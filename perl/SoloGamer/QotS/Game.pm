package SoloGamer::QotS::Game;

use v5.42;

use Carp;
use Moose;
use namespace::autoclean;

use SoloGamer::QotS::CombatState;

extends 'SoloGamer::Game';

after 'BUILD' => sub {
  my $self = shift;
  
  # Display welcome banner at the very start, before plane/crew naming
  $self->buffer_header("Welcome to B-17 Queen of the Skies", 40);
  $self->print_output;
  
  return;
};

override 'substitute_variables' => sub {
  my ($self, $text) = @_;
  
  # Call parent method first
  $text = super();
  
  $text =~ s/\$plane_name/$self->save->get_plane_name/egx;
  return $text;
};

override 'smart_buffer' => sub {
  my ($self, $text) = @_;
  
  return unless defined $text && length $text;
  
  # Apply variable substitution first
  $text = $self->substitute_variables($text);
  
  # QotS-specific text pattern matching using dispatch table
  my @patterns = (
    [ qr/^Rolling for/ixms, sub {
      # Add mission number before Rolling for Mission
      if ($text =~ /Rolling for Mission/ixms) {
        my $mission = $self->save->mission;
        $self->buffer_header("MISSION $mission", 40);
      }
      $self->buffer_roll($text);
    }],
    [ qr/^Welcome to/ixms, sub {
      # Display Welcome message
      $self->buffer_header($text, 40);
    }],
    [ qr/safe|successful|On target/ixms, sub {
      $self->buffer_success($text);
    }],
    [ qr/damage|hit|fail|crash/ixms, sub {
      $self->buffer_danger($text);
    }],
    [ qr/Moving to zone|zone:/ixms, sub {
      $self->buffer_location($text);
    }],
    [ qr/Target:|Type:|Formation|Percent/ixms, sub {
      $self->buffer_important($text);
    }],
  );
  
  # Apply first matching pattern
  foreach my $pattern_pair (@patterns) {
    my ($pattern, $handler) = @$pattern_pair;
    if ($text =~ $pattern) {
      $handler->();
      return;
    }
  }
  
  # Default case
  $self->buffer($text);
  
  return;
};

override 'run_game' => sub {
  my $self = shift;

  $self->devel("In run_game");
  my $mission = $self->save->mission;
  my $max_missions = $self->tables->{'FLOW-start'}->{'data'}->{'missions'};
  $mission > $max_missions and croak "25 successful missions, your crew went home!";

  # Initialize aircraft state if needed
  unless ($self->save->aircraft_state) {
    $self->devel("Initializing aircraft state for mission");
    # The SaveGame _build_aircraft_state will create or load it
    $self->save->aircraft_state;
  }
  
  # Initialize combat state for the mission
  $self->devel("Initializing combat state for mission");
  $self->save->combat_state(SoloGamer::QotS::CombatState->new());

  # Display crew roster at start of mission
  if ($self->save->crew) {
    my $roster = $self->save->crew->display_roster();
    $self->buffer($roster);
  }

  $self->do_flow('FLOW-start');

  # Report mission outcome at end
  $self->report_mission_outcome();
  $self->print_output;

  $self->save->save_game;
  return;
};

sub zone_process {
  my $self = shift;
  
  my $current_zone = $self->zone;
  $self->devel("Processing zone: $current_zone");
  
  # Reset combat state for this zone
  $self->save->reset_combat_for_zone($current_zone);
  
  # Determine which table to use based on zone type
  # For now, use B-1 for non-target zones
  # TODO: Detect target zone and use B-2 instead
  
  # Roll for fighter encounters (B-1 or B-2)
  my $b1_roll = $self->do_roll('B-1');
  if ($b1_roll) {
    my $fighter_waves = $b1_roll->{'fighter_waves'} || 0;
    $self->handle_output('fighter_waves', $fighter_waves, "Fighter waves: <1>");
    
    # Process each wave
    for (my $wave = 1; $wave <= $fighter_waves; $wave++) {
      $self->smart_buffer("Processing fighter wave $wave of $fighter_waves");
      
      # Roll for fighter composition (B-3)
      my $b3_roll = $self->do_roll('B-3');
      if ($b3_roll && exists $b3_roll->{'fighters'}) {
        my $fighters = $b3_roll->{'fighters'};
        my $num_fighters = scalar(@$fighters);
        
        if ($num_fighters > 0) {
          $self->handle_output('num_fighters', $num_fighters, "<1> fighter(s) in wave $wave");
          # Process fighter combat for this wave
          $self->process_fighter_combat($fighters);
        } else {
          $self->smart_buffer("No attackers - fighters driven off");
        }
      }
    }
  }
  
  # Check for flak near target (would need zone type info)
  # For now, simplified - could be enhanced with zone metadata
  
  return;
}

sub process_fighter_combat {
  my $self = shift;
  my $fighters = shift;
  
  my $num_fighters = scalar(@$fighters);
  $self->devel("Processing combat with $num_fighters fighters");
  
  # Initialize combat state for this wave
  if ($self->save->combat_state) {
    $self->save->combat_state->start_new_wave({
      zone => $self->zone,
      fighters => $fighters,
    });
    
    # Add fighters to combat state
    foreach my $fighter (@$fighters) {
      $self->save->combat_state->add_fighter($fighter);
    }
  }
  
  # Check fighter cover
  my $fighter_cover = $self->save->get_from_current_mission('fighter_cover') || 'none';
  if ($fighter_cover ne 'none' && $fighter_cover ne 'None') {
    # Roll M-4 for fighter cover effectiveness
    my $m4_roll = $self->do_roll('M-4');
    if ($m4_roll) {
      $self->handle_output('cover_result', $m4_roll->{'result'}, "Fighter cover: <1>");
    }
  }
  
  # Process each fighter's attack
  # This would ideally use FLOW-fighter-attack but for now simplified
  foreach my $fighter (@$fighters) {
    $self->process_fighter_attack($fighter);
  }
  
  return;
}

sub process_fighter_attack {
  my $self = shift;
  my $fighter = shift;
  
  my $type = $fighter->{'type'} || 'Me109';
  my $position = $fighter->{'position'} || '12 High';
  
  $self->smart_buffer("$type attacking from $position");
  
  # Get M-1 table for defensive fire positions
  my $m1_table = $self->tables->{'M-1'};
  return unless $m1_table;
  
  # Normalize position for lookup (replace : with _ and spaces with _)
  my $lookup_position = lc($position);
  $lookup_position =~ s/:|\s+/_/gxms;
  
  # Get guns that can fire at this position
  my $guns_available = $m1_table->{'data'}->{'gun_positions'}->{$lookup_position} || {};
  
  # Process defensive fire
  my $fighter_damage = "";
  foreach my $gun (keys %$guns_available) {
    my $to_hit = $guns_available->{$gun};
    
    # Check if gun is operational (would check AircraftState in full implementation)
    # For now assume all guns work
    
    # Roll for hit
    my $roll = int(rand(6) + 1);
    $self->devel("$gun fires at $type: rolled $roll, needs $to_hit to hit");
    
    if ($roll >= $to_hit) {
      $self->buffer_success("$gun hits the $type!");
      
      # Roll M-2 for damage
      my $m2_roll = $self->do_roll('M-2');
      if ($m2_roll && exists $m2_roll->{'result'}) {
        my $result = $m2_roll->{'result'};
        if ($result eq 'FCA') {
          $fighter_damage = 'FCA';
          $self->smart_buffer("Fighter damaged, continuing attack with -1");
        } elsif ($result eq 'FBOA') {
          $self->smart_buffer("Fighter breaks off attack!");
          return; # Fighter driven off
        } elsif ($result eq 'Destroyed') {
          $self->buffer_success("Fighter destroyed!");
          # Award kill to gunner (would update CrewMember in full implementation)
          return; # Fighter destroyed
        }
      }
    }
  }
  
  # Fighter attacks (M-3)
  my $m3_table = $self->tables->{'M-3'};
  if ($m3_table) {
    # Determine attack position category
    my $attack_category = $self->get_attack_category($position);
    
    # Get hit requirements for this fighter type and position
    my $attack_data = $m3_table->{'data'}->{'attack_position'}->{$attack_category}->{$type} || {};
    my $hit_on = $attack_data->{'hit_on'} || [];
    
    # Roll for fighter attack
    my $attack_roll = int(rand(6) + 1);
    
    # Apply damage modifier if fighter was hit
    if ($fighter_damage eq 'FCA') {
      $attack_roll -= 1;
    }
    
    $self->devel("$type attacks: rolled $attack_roll (modified), needs " . join(",", @$hit_on) . " to hit");
    
    # Check if hit (6 always hits regardless of modifiers)
    if ($attack_roll == 6 || grep {$_ == $attack_roll} @$hit_on) {
      $self->buffer_danger("B-17 hit by $type!");
      # Would roll damage tables here (P-series)
    } else {
      $self->smart_buffer("$type misses");
    }
  }
  
  return;
}

sub get_attack_category {
  my $self = shift;
  my $position = shift;
  
  # Map specific positions to M-3 categories
  SWITCH: for ($position) {
    return 'vertical_dive' if /veritical\s+dive/imxs;
    return 'vertical_climb' if /veritical\s+climb/imxs;
    return '12_high_level_low' if /^12\s+(high|level|low)/ixms;
    return '6_high_level_low' if /^6\s+(high|level|low)/ixms;
    return '3_9_high_level_low' if /^(3|9)\s+(high|level|low)/ixms;
    return '10:30_1:30_high_level_low' if /^(10:30|1:30)\s+(high|level|low)/ixms;
  }
  
  return '12_high_level_low'; # Default
}

sub report_mission_outcome {
  my $self = shift;
  
  my $mission = $self->save->mission;
  my $landing_result = $self->save->get_from_current_mission('landing');
  
  # Determine mission outcome based on landing result
  my $outcome = "UNKNOWN";
  my $game_over = 0;
  
  if ($landing_result) {
    # Use dispatch table for outcome determination
    my @outcome_patterns = (
      [ qr/wrecked|KIA/ixms, sub {
        $outcome = "MISSION FAILED - B-17 WRECKED";
        $game_over = 1;
      }],
      [ qr/irrepairably damaged/ixms, sub {
        $outcome = "MISSION FAILED - B-17 IRREPARABLY DAMAGED";
        $game_over = 1;
      }],
      [ qr/repairable/ixms, sub {
        $outcome = "MISSION SUCCESS - B-17 DAMAGED BUT REPAIRABLE";
      }],
      [ qr/safe/ixms, sub {
        $outcome = "MISSION SUCCESS - CREW AND B-17 SAFE";
      }],
    );
    
    # Apply first matching pattern
    foreach my $pattern_pair (@outcome_patterns) {
      my ($pattern, $handler) = @$pattern_pair;
      if ($landing_result =~ $pattern) {
        $handler->();
        last;
      }
    }
  }
  
  # Update crew mission counts for successful missions
  if ($self->save->crew && !$game_over) {
    $self->save->update_crew_after_mission();
  }
  
  # Display outcome
  $self->buffer_header("MISSION $mission OUTCOME", 40);
  $self->buffer_success($outcome);
  
  # Display updated crew roster after mission
  if ($self->save->crew) {
    my $roster = $self->save->crew->display_roster();
    $self->buffer($roster);
  }
  
  if ($game_over) {
    $self->buffer_header("PLAYTHROUGH OVER", 40);
  }
  
  return;
}

__PACKAGE__->meta->make_immutable;
1;