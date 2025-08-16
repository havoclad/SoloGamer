package SoloGamer::QotS::Game;

use v5.42;

use Carp;
use Moose;
use namespace::autoclean;

use SoloGamer::QotS::CombatState;

extends 'SoloGamer::Game';

override 'substitute_variables' => sub {
  my ($self, $text) = @_;
  
  # Call parent method first
  $text = super();
  
  return $text unless defined $text && length $text;
  
  # Substitute plane name variable (QotS-specific)
  if ($text =~ /\$plane_name/) {
    my $plane_name = $self->save->get_plane_name();
    $text =~ s/\$plane_name/$plane_name/g;
  }
  
  return $text;
};

override 'smart_buffer' => sub {
  my ($self, $text) = @_;
  
  return unless defined $text && length $text;
  
  # Apply variable substitution first
  $text = $self->substitute_variables($text);
  
  # QotS-specific text pattern matching
  if ($text =~ /^Rolling for/i) {
    # Add mission number before Rolling for Mission
    if ($text =~ /Rolling for Mission/i) {
      my $mission = $self->save->mission;
      $self->buffer_header("MISSION $mission", 40);
    }
    $self->buffer_roll($text);
  } elsif ($text =~ /^Welcome to/i) {
    # Display Welcome message
    $self->buffer_header($text, 40);
  } elsif ($text =~ /safe|successful|On target/i) {
    $self->buffer_success($text);
  } elsif ($text =~ /damage|hit|fail|crash/i) {
    $self->buffer_danger($text);
  } elsif ($text =~ /Moving to zone|zone:/i) {
    $self->buffer_location($text);
  } elsif ($text =~ /Target:|Type:|Formation|Percent/i) {
    $self->buffer_important($text);
  } else {
    $self->buffer($text);
  }
  
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
  $lookup_position =~ s/:/_/g;
  $lookup_position =~ s/\s+/_/g;
  
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
  if ($position =~ /vertical\s+dive/i) {
    return 'vertical_dive';
  } elsif ($position =~ /vertical\s+climb/i) {
    return 'vertical_climb';
  } elsif ($position =~ /^12\s+(high|level|low)/i) {
    return '12_high_level_low';
  } elsif ($position =~ /^6\s+(high|level|low)/i) {
    return '6_high_level_low';
  } elsif ($position =~ /^(3|9)\s+(high|level|low)/i) {
    return '3_9_high_level_low';
  } elsif ($position =~ /^(10:30|1:30)\s+(high|level|low)/i) {
    return '10:30_1:30_high_level_low';
  }
  
  # Default
  return '12_high_level_low';
}

sub report_mission_outcome {
  my $self = shift;
  
  my $mission = $self->save->mission;
  my $landing_result = $self->save->get_from_current_mission('landing');
  
  # Determine mission outcome based on landing result
  my $outcome = "UNKNOWN";
  my $game_over = 0;
  
  if ($landing_result) {
    if ($landing_result =~ /wrecked|KIA/i) {
      $outcome = "MISSION FAILED - B-17 WRECKED";
      $game_over = 1;
    } elsif ($landing_result =~ /irrepairably damaged/i) {
      $outcome = "MISSION FAILED - B-17 IRREPARABLY DAMAGED";
      $game_over = 1;
    } elsif ($landing_result =~ /repairable/i) {
      $outcome = "MISSION SUCCESS - B-17 DAMAGED BUT REPAIRABLE";
    } elsif ($landing_result =~ /safe/i) {
      $outcome = "MISSION SUCCESS - CREW AND B-17 SAFE";
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