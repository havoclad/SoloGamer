package SoloGamer::QotS::DamageResolver;

use v5.42;

use Moose;
use namespace::autoclean;
use Carp;

with 'Logger';

has 'aircraft_state' => (
  is       => 'rw',
  isa      => 'SoloGamer::QotS::AircraftState',
  required => 1,
);

has 'crew' => (
  is       => 'rw',
  isa      => 'SoloGamer::QotS::Crew',
  required => 1,
);

sub resolve_damage {
  my $self = shift;
  my $damage_result = shift;
  my $target_crew_member = shift;  # Optional parameter for follow-up tables

  unless ($damage_result && ref($damage_result) eq 'HASH') {
    $self->devel('Warning: Invalid damage result passed to resolve_damage');
    return;
  }

  my @damage_reports = ();

  # Handle structured damage effects if present
  if (exists $damage_result->{damage_effects}) {
    foreach my $effect (@{$damage_result->{damage_effects}}) {
      # Replace target_crew_member placeholder with actual position
      if ($effect->{position} eq 'target_crew_member' && $target_crew_member) {
        $effect->{position} = $target_crew_member;
      }

      my $report = $self->_apply_damage_effect($effect);
      push @damage_reports, $report if $report;
    }
  }

  # Handle legacy text-based damage parsing as fallback
  if (exists $damage_result->{result} && !exists $damage_result->{damage_effects}) {
    my $report = $self->_parse_and_apply_text_damage($damage_result->{result});
    push @damage_reports, $report if $report;
  }

  return @damage_reports;
}

sub _apply_damage_effect {
  my $self = shift;
  my $effect = shift;

  my $type = $effect->{type} || 'unknown';
  my $report = '';

  EFFECT_TYPE: for ($type) {
    if (/^crew_wound$/x) {
      $report = $self->_apply_crew_wound($effect);
      last EFFECT_TYPE;
    }
    if (/^engine_damage$/x) {
      $report = $self->_apply_engine_damage($effect);
      last EFFECT_TYPE;
    }
    if (/^gun_damage$/x) {
      $report = $self->_apply_gun_damage($effect);
      last EFFECT_TYPE;
    }
    if (/^fuel_damage$/x) {
      $report = $self->_apply_fuel_damage($effect);
      last EFFECT_TYPE;
    }
    if (/^structural_damage$/x) {
      $report = $self->_apply_structural_damage($effect);
      last EFFECT_TYPE;
    }
    if (/^control_damage$/x) {
      $report = $self->_apply_control_damage($effect);
      last EFFECT_TYPE;
    }
    if (/^equipment_damage$/x) {
      $report = $self->_apply_equipment_damage($effect);
      last EFFECT_TYPE;
    }
    # Default case
    $self->devel("Warning: Unknown damage effect type: $type");
  }

  return $report;
}

sub _apply_crew_wound {
  my $self = shift;
  my $effect = shift;

  my $position = $effect->{position} || 'unknown';
  my $severity = $effect->{severity} || 'light';
  my $location = $effect->{location} || 'unspecified';

  my $crew_member = $self->crew->get_crew_member($position);
  unless ($crew_member) {
    $self->devel("Warning: No crew member found at position: $position");
    return "No crew member at $position to wound";
  }

  $crew_member->apply_wound($severity, $location);

  my $name = $crew_member->name;
  if ($severity eq 'mortal') {
    return "$name ($position) killed instantly by $location wound";
  } elsif ($severity eq 'serious') {
    return "$name ($position) seriously wounded in $location";
  } else {
    return "$name ($position) lightly wounded in $location";
  }
}

sub _apply_engine_damage {
  my $self = shift;
  my $effect = shift;

  my $engine_num = $effect->{engine} || 1;
  my $damage_type = $effect->{damage_type} || 'out';

  my $status = $self->aircraft_state->damage_engine($engine_num, $damage_type);

  my $engine_pos = $self->aircraft_state->engines->{$engine_num}->{position} || "Engine $engine_num";

  DAMAGE_REPORT: for ($damage_type) {
    if (/^fire$/x) {
      return "$engine_pos on fire!";
    }
    if (/^out$/x) {
      return "$engine_pos knocked out";
    }
    if (/^runaway$/x) {
      return "$engine_pos running away - must be feathered!";
    }
    if (/^oil_tank$/x) {
      return "$engine_pos oil tank hit - engine failing";
    }
    if (/^supercharger$/x) {
      return "$engine_pos supercharger damaged";
    }
    # Default
    return "$engine_pos damaged ($damage_type)";
  }
}

sub _apply_gun_damage {
  my $self = shift;
  my $effect = shift;

  my $gun_position = $effect->{position} || 'nose';
  my $damage_type = $effect->{damage_type} || 'jam';

  if ($damage_type eq 'destroy') {
    $self->aircraft_state->destroy_gun($gun_position);
    return "$gun_position gun destroyed!";
  } elsif ($damage_type eq 'jam') {
    $self->aircraft_state->jam_gun($gun_position);
    return "$gun_position gun jammed";
  }

  return "$gun_position gun damaged";
}

sub _apply_fuel_damage {
  my $self = shift;
  my $effect = shift;

  my $tank = $effect->{tank} || 'port_outer';
  my $damage_type = $effect->{damage_type} || 'leak';

  my $status = $self->aircraft_state->hit_fuel_tank($tank, $damage_type);

  FUEL_REPORT: for ($damage_type) {
    if (/^fire$/x) {
      return "$tank fuel tank on fire!";
    }
    if (/^explosion$/x) {
      return "$tank fuel tank exploded!";
    }
    if (/^leak$/x) {
      if ($status eq 'self_sealed') {
        return "$tank fuel tank hit but self-sealed";
      } else {
        return "$tank fuel tank leaking";
      }
    }
    # Default
    return "$tank fuel tank damaged";
  }
}

sub _apply_structural_damage {
  my $self = shift;
  my $effect = shift;

  my $compartment = $effect->{compartment} || 'nose';
  my $damage_type = $effect->{damage_type} || 'hit';

  $self->aircraft_state->add_structural_damage($compartment, $damage_type);

  if ($damage_type eq 'superficial') {
    return "Superficial damage to $compartment";
  } else {
    return "Structural hit to $compartment";
  }
}

sub _apply_control_damage {
  my $self = shift;
  my $effect = shift;

  my $surface = $effect->{surface} || 'rudder';
  my $severity = $effect->{severity} || 1;

  my $status = $self->aircraft_state->damage_control_surface($surface, $severity);

  if ($status eq 'inoperable') {
    return "$surface shot away - aircraft hard to control!";
  } elsif ($status eq 'damaged') {
    return "$surface damaged - reduced control";
  } else {
    return "$surface lightly damaged";
  }
}

sub _apply_equipment_damage {
  my $self = shift;
  my $effect = shift;

  my $equipment = $effect->{equipment} || 'unknown';
  my $modifier = $effect->{modifier} || 0;

  # This is where we'd apply modifiers to navigation, bombing accuracy, etc.
  # For now, just report the damage
  return "$equipment damaged" . ($modifier < 0 ? " (penalty: $modifier)" : "");
}

sub _parse_and_apply_text_damage {
  my $self = shift;
  my $text = shift;

  # Basic text parsing for legacy support
  # This is a fallback - structured damage_effects are preferred

  if ($text =~ /navigator.*wounded/xi) {
    my $navigator = $self->crew->get_crew_member('navigator');
    if ($navigator) {
      $navigator->apply_wound('light', 'unspecified');
      return $navigator->name . " (navigator) wounded";
    }
  }

  if ($text =~ /bombardier.*wounded/xi) {
    my $bombardier = $self->crew->get_crew_member('bombardier');
    if ($bombardier) {
      $bombardier->apply_wound('light', 'unspecified');
      return $bombardier->name . " (bombardier) wounded";
    }
  }

  # Add more text parsing patterns as needed
  return "Damage: $text";
}

__PACKAGE__->meta->make_immutable;
1;