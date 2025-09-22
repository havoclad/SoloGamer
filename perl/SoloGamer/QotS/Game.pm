package SoloGamer::QotS::Game;

use v5.42;

use Carp;
use Moose;
use namespace::autoclean;

use SoloGamer::QotS::CombatState;
use SoloGamer::QotS::DamageResolver;

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

override 'handle_output' => sub {
  my ($self, $field, $value, $template) = @_;

  # Debug: Log all parameters to see what we're getting
  $self->devel("handle_output called: field='$field', value='" . ($value || 'undef') . "', template='" . ($template || 'undef') . "'");

  # Call parent method first
  super();

  # Intercept flak hits for damage processing
  # Check for flak hits in various forms
  my $flak_hits = 0;

  if ($template && $template =~ /(\d+)\s+flak\s+hits?\s+to\s+the\s+B-17/i) {
    $flak_hits = $1;
    $self->devel("Found flak hits in template: $flak_hits");
  } elsif ($value && $value =~ /(\d+)\s+flak\s+hits?\s+to\s+the\s+B-17/i) {
    $flak_hits = $1;
    $self->devel("Found flak hits in value: $flak_hits");
  } elsif ($template && $template =~ /<(\d+)>\s+flak\s+hit\(s\)\s+to\s+the\s+B-17/i) {
    $flak_hits = $1;
    $self->devel("Found flak hits in template with brackets: $flak_hits");
  }

  if ($flak_hits > 0) {
    $self->devel("Processing $flak_hits flak hits");
    $self->resolve_flak_damage($flak_hits);
  }

  return;
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
    [ qr/^Moving\s+to\s+zone/ixms, sub {
      # Display zone transitions with box headers
      $self->buffer_header($text, 30);
    }],
    [ qr/safe|successful|On target/ixms, sub {
      $self->buffer_success($text);
    }],
    [ qr/damage|hit|fail|crash/ixms, sub {
      $self->buffer_danger($text);
    }],
    [ qr/zone:/ixms, sub {
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

  $self->devel('In run_game');
  my $mission = $self->save->mission;
  my $max_missions = $self->tables->{'FLOW-start'}->{data}->{missions};
  $mission > $max_missions and croak "25 successful missions, your crew went home!";

  # Initialize aircraft state if needed
  unless ($self->save->aircraft_state) {
    $self->devel('Initializing aircraft state for mission');
    # The SaveGame _build_aircraft_state will create or load it
    $self->save->aircraft_state;
  }
  
  # Initialize combat state for the mission
  $self->devel('Initializing combat state for mission');
  $self->save->combat_state(SoloGamer::QotS::CombatState->new());

  # Replace any dead crew members before mission start
  if ($self->save->crew) {
    $self->_replace_dead_crew_members();
  }

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
    my $fighter_waves = $b1_roll->{fighter_waves} || 0;
    $self->handle_output('fighter_waves', $fighter_waves, "Fighter waves: <1>");
    
    # Process each wave
    for (my $wave = 1; $wave <= $fighter_waves; $wave++) {
      $self->smart_buffer("Processing fighter wave $wave of $fighter_waves");
      
      # Roll for fighter composition (B-3)
      my $b3_roll = $self->do_roll('B-3');
      if ($b3_roll && exists $b3_roll->{fighters}) {
        my $fighters = $b3_roll->{fighters};
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
      $self->handle_output('cover_result', $m4_roll->{result}, "Fighter cover: <1>");
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
  
  my $type = $fighter->{type} || 'Me109';
  my $position = $fighter->{position} || '12 High';
  
  $self->smart_buffer("$type attacking from $position");
  
  # Get M-1 table for defensive fire positions
  my $m1_table = $self->tables->{'M-1'};
  return unless $m1_table;
  
  # Normalize position for lookup (replace : with _ and spaces with _)
  my $lookup_position = lc($position);
  $lookup_position =~ s/:|\s+/_/gxms;
  
  # Get guns that can fire at this position
  my $guns_available = $m1_table->{data}->{gun_positions}->{$lookup_position} || {};
  
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
      if ($m2_roll && exists $m2_roll->{result}) {
        my $result = $m2_roll->{result};
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
    my $attack_data = $m3_table->{data}->{attack_position}->{$attack_category}->{$type} || {};
    my $hit_on = $attack_data->{hit_on} || [];
    
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

      # Roll for number of shell hits (would typically use B-4 table)
      # For now, assume 1 shell hit for simplicity
      my $shell_hits = 1;
      $self->smart_buffer("$shell_hits shell hit(s) from $type");

      # Process each shell hit with attack position info
      for (my $hit = 1; $hit <= $shell_hits; $hit++) {
        $self->resolve_aircraft_damage($position, 'high'); # Pass fighter position and altitude
      }
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

sub resolve_flak_damage {
  my $self = shift;
  my $flak_hits = shift || 1;

  $self->buffer_danger("$flak_hits flak hit(s) on the B-17!");

  # Process each flak hit
  for (my $hit = 1; $hit <= $flak_hits; $hit++) {
    if ($flak_hits > 1) {
      $self->smart_buffer("Processing flak hit $hit of $flak_hits");
    }
    $self->resolve_aircraft_damage();
  }

  return;
}

sub resolve_aircraft_damage {
  my $self = shift;
  my $attack_position = shift; # Optional - for fighter attacks
  my $altitude = shift;        # Optional - for fighter attacks

  # Ensure we have aircraft and crew objects
  unless ($self->save->aircraft_state && $self->save->crew) {
    $self->devel('Warning: Cannot resolve damage - missing aircraft state or crew');
    return;
  }

  # Create damage resolver
  my $resolver = SoloGamer::QotS::DamageResolver->new(
    aircraft_state => $self->save->aircraft_state,
    crew          => $self->save->crew,
  );

  # Phase 3: Enhanced damage resolution with proper location determination
  $self->buffer_header("DAMAGE RESOLUTION", 40);

  # Step 1: Determine hit location using B-5 table or default
  my ($hit_location, $damage_table) = $self->determine_hit_location($attack_position, $altitude);

  $self->smart_buffer("Hit Location: $hit_location");
  $self->smart_buffer("Rolling on Table $damage_table");

  # Step 2: Roll damage table with full visibility
  my $damage_result = $self->do_roll_with_display($damage_table);
  unless ($damage_result) {
    $self->devel("Warning: No result from $damage_table damage table");
    return;
  }

  # Step 3: Show the damage result description
  if (exists $damage_result->{result}) {
    $self->buffer_important("Table Result: " . $damage_result->{result});
  }
  if (exists $damage_result->{description}) {
    $self->smart_buffer($damage_result->{description});
  }

  # Step 4: Resolve any follow-up tables (like BL-4 for crew wounds)
  $self->resolve_follow_up_tables($damage_result, $resolver);

  # Step 5: Apply the actual damage using DamageResolver
  my @damage_reports = $resolver->resolve_damage($damage_result);

  # Step 6: Display final damage summary
  if (@damage_reports) {
    $self->buffer_header("DAMAGE APPLIED", 30);
    foreach my $report (@damage_reports) {
      if ($report) {
        $self->buffer_danger("* $report");
      }
    }
  }

  return;
}

sub get_damage_table_for_location {
  my $self = shift;
  my $location = shift;

  # Map hit locations to P-series damage tables
  LOCATION_SWITCH: for ($location) {
    return 'P-1' if /nose/ixms;
    return 'P-2' if /pilot/ixms;
    return 'P-3' if /bomb.*bay/ixms;
    return 'P-4' if /radio/ixms;
    return 'P-5' if /waist/ixms;
    return 'P-6' if /tail/ixms;
  }

  # Default to nose for unknown locations
  return 'P-1';
}

sub do_roll_with_display {
  my $self = shift;
  my $table_name = shift;

  # Call the parent do_roll method
  my $result = $self->do_roll($table_name);

  # Display the roll details if available
  if ($self->tables->{$table_name}->can('get_last_roll_details')) {
    my $roll_details = $self->tables->{$table_name}->get_last_roll_details();
    if ($roll_details) {
      my $individual_rolls = $roll_details->{individual_rolls} || [];
      my $roll_display = join(', ', @$individual_rolls);
      my $raw_result = $roll_details->{raw_result} || 0;
      my $modifiers = $roll_details->{modifiers} || 0;
      my $final_result = $roll_details->{final_result} || 0;

      if (@$individual_rolls > 1) {
        $self->buffer_roll("Rolling [$roll_display] = $raw_result");
      } else {
        $self->buffer_roll("Rolling $raw_result");
      }

      if ($modifiers != 0) {
        my $modifier_text = $modifiers > 0 ? "+$modifiers" : "$modifiers";
        $self->buffer_roll("Modified: $raw_result $modifier_text = $final_result");
      }
    }
  }

  return $result;
}

sub resolve_follow_up_tables {
  my $self = shift;
  my $damage_result = shift;
  my $resolver = shift;

  # Check if this result has follow-up tables to roll
  if (exists $damage_result->{follow_up}) {
    my $follow_up = $damage_result->{follow_up};
    my $follow_table = $follow_up->{table};
    my $target = $follow_up->{target} || 'crew member';

    $self->smart_buffer("$target requires follow-up roll");
    $self->smart_buffer("Rolling on Table $follow_table");

    # Roll the follow-up table
    my $follow_result = $self->do_roll_with_display($follow_table);

    if ($follow_result) {
      # Display follow-up result
      if (exists $follow_result->{result}) {
        $self->buffer_important("$follow_table Result: " . $follow_result->{result});
      }
      if (exists $follow_result->{description}) {
        $self->smart_buffer($follow_result->{description});
      }

      # Apply follow-up damage if it has damage_effects
      if (exists $follow_result->{damage_effects}) {
        # Extract target crew member position from the original damage result
        my $target_position = lc($target);
        $target_position =~ s/\s+/_/g;  # Convert "Navigator" to "navigator", etc.

        my @follow_reports = $resolver->resolve_damage($follow_result, $target_position);
        foreach my $report (@follow_reports) {
          if ($report) {
            $self->buffer_danger("Follow-up: $report");
          }
        }
      }
    }
  }

  # Check for sub-rolls (like Navigator's Equipment)
  if (exists $damage_result->{sub_roll}) {
    my $sub_roll = $damage_result->{sub_roll};
    my $roll_type = $sub_roll->{type} || '1d6';

    $self->smart_buffer("Sub-roll required: $roll_type");

    # Simple sub-roll implementation for now
    my $sub_result = int(rand(6) + 1);
    $self->buffer_roll("Sub-roll: $sub_result");

    # Check sub-roll results
    foreach my $range (keys %$sub_roll) {
      next if $range eq 'type';

      if ($range =~ /^(\d+)-(\d+)$/) {
        my ($min, $max) = ($1, $2);
        if ($sub_result >= $min && $sub_result <= $max) {
          $self->buffer_important("Sub-roll Result: " . $sub_roll->{$range});
          last;
        }
      }
    }
  }

  return;
}

sub determine_hit_location {
  my $self = shift;
  my $attack_position = shift || 'unknown';
  my $altitude = shift || 'high';

  # For flak or unknown attacks, roll on B-5 using a default position
  # For fighter attacks, we should have position and altitude data

  if ($attack_position eq 'unknown') {
    # Default to flak-like random location for now
    # In a full implementation, this would determine based on combat context
    return $self->roll_random_location();
  }

  # Use B-5 table structure to determine location
  return $self->roll_b5_location($attack_position, $altitude);
}

sub roll_random_location {
  my $self = shift;

  # For flak or unknown attacks, use a simplified random distribution
  my @locations = (
    ['Nose Compartment', 'P-1'],
    ['Pilot Compartment', 'P-2'],
    ['Bomb Bay', 'P-3'],
    ['Radio Room', 'P-4'],
    ['Waist', 'P-5'],
    ['Tail', 'P-6'],
    ['Superficial', 'none'],
  );

  my $roll = int(rand(scalar(@locations)));
  my ($location, $table) = @{$locations[$roll]};

  if ($table eq 'none') {
    # Superficial damage - just note it but no table roll needed
    $self->smart_buffer("Superficial damage - no significant effect");
    return ('Superficial', 'P-1'); # Still return P-1 as fallback
  }

  return ($location, $table);
}

sub roll_b5_location {
  my $self = shift;
  my $attack_position = shift;
  my $altitude = shift;

  # This method would implement the full B-5 table logic
  # For Phase 3, implementing a simplified version that covers main cases

  # Normalize attack position for B-5 lookup
  my $b5_position = $self->normalize_attack_position_for_b5($attack_position);

  # Roll 2d6 for location
  my $location_roll = int(rand(6) + 1) + int(rand(6) + 1);
  $self->smart_buffer("Rolling for hit location: $location_roll");

  # Simplified B-5 logic - implement core positions
  if ($b5_position eq '12_1:30_10:30') {
    return $self->get_b5_12_high_result($location_roll);
  } elsif ($b5_position eq '6') {
    return $self->get_b5_6_result($location_roll, $altitude);
  } elsif ($b5_position eq '3_9') {
    return $self->get_b5_3_9_result($location_roll, $altitude);
  }

  # Default fallback to nose
  return ('Nose Compartment', 'P-1');
}

sub normalize_attack_position_for_b5 {
  my $self = shift;
  my $position = shift;

  # Map fighter attack positions to B-5 categories
  return '12_1:30_10:30' if $position =~ /12|1:30|10:30/i;
  return '6' if $position =~ /6/i;
  return '3_9' if $position =~ /^[39]/i;

  # Default to 12 o'clock attacks
  return '12_1:30_10:30';
}

sub get_b5_12_high_result {
  my $self = shift;
  my $roll = shift;

  # Simplified B-5 table for 12 o'clock high attacks
  my %results = (
    2 => ['Superficial', 'P-1'],
    3 => ['Superficial', 'P-1'],
    4 => ['Superficial', 'P-1'],
    5 => ['Radio Room', 'P-4'],
    6 => ['Nose', 'P-1'],
    7 => ['Pilot Compartment', 'P-2'],
    8 => ['Wings', 'BL-1'],
    9 => ['Waist', 'P-5'],
    10 => ['Tail', 'P-6'],
    11 => ['Bomb Bay', 'P-3'],
    12 => ['Walking Hits/Fuselage', 'walking_hits_a'],
  );

  if (exists $results{$roll}) {
    my ($location, $table) = @{$results{$roll}};

    # Handle special cases
    if ($table eq 'walking_hits_a') {
      return $self->handle_walking_hits_a();
    } elsif ($table eq 'BL-1') {
      return $self->handle_wing_hit();
    }

    return ($location, $table);
  }

  # Fallback
  return ('Nose Compartment', 'P-1');
}

sub get_b5_6_result {
  my $self = shift;
  my $roll = shift;
  my $altitude = shift;

  # Simplified 6 o'clock attacks - mainly tail area
  my %high_results = (
    2 => ['Superficial', 'P-1'],
    3 => ['Superficial', 'P-1'],
    4 => ['Radio Room', 'P-4'],
    5 => ['Bomb Bay', 'P-3'],
    6 => ['Port Wing', 'BL-1'],
    7 => ['Tail', 'P-6'],
    8 => ['Starboard Wing', 'BL-1'],
    9 => ['Waist', 'P-5'],
    10 => ['Pilot Compartment', 'P-2'],
    11 => ['Walking Hits/Fuselage', 'walking_hits_a'],
    12 => ['Nose', 'P-1'],
  );

  if (exists $high_results{$roll}) {
    my ($location, $table) = @{$high_results{$roll}};

    if ($table eq 'walking_hits_a') {
      return $self->handle_walking_hits_a();
    } elsif ($table eq 'BL-1') {
      return $self->handle_wing_hit();
    }

    return ($location, $table);
  }

  return ('Tail', 'P-6'); # 6 o'clock bias toward tail
}

sub get_b5_3_9_result {
  my $self = shift;
  my $roll = shift;
  my $altitude = shift;

  # 3/9 o'clock attacks - side attacks
  my %results = (
    2 => ['Walking Hits/Wings', 'walking_hits_b'],
    3 => ['Nose', 'P-1'],
    4 => ['Pilot Compartment', 'P-2'],
    5 => ['Bomb Bay', 'P-3'],
    6 => ['Port Wing', 'BL-1'],
    7 => ['Tail', 'P-6'],
    8 => ['Starboard Wing', 'BL-1'],
    9 => ['Radio Room', 'P-4'],
    10 => ['Waist', 'P-5'],
    11 => ['Superficial', 'P-1'],
    12 => ['Walking Hits/Fuselage', 'walking_hits_a'],
  );

  if (exists $results{$roll}) {
    my ($location, $table) = @{$results{$roll}};

    if ($table eq 'walking_hits_a') {
      return $self->handle_walking_hits_a();
    } elsif ($table eq 'walking_hits_b') {
      return $self->handle_walking_hits_b();
    } elsif ($table eq 'BL-1') {
      return $self->handle_wing_hit();
    }

    return ($location, $table);
  }

  return ('Waist', 'P-5'); # Side attack bias
}

sub handle_wing_hit {
  my $self = shift;

  # For now, treat wing hits as superficial since we don't have BL-1 implemented yet
  $self->smart_buffer("Wing hit - treating as superficial damage for now");
  return ('Wing (Superficial)', 'P-1');
}

sub handle_walking_hits_a {
  my $self = shift;

  # Walking hits A: Nose, Pilot, Bomb Bay, Radio, Waist, Tail
  $self->smart_buffer("Walking hits across fuselage - multiple compartments hit!");
  $self->smart_buffer("Processing hits to: Nose, Pilot, Bomb Bay, Radio, Waist, Tail");

  # For Phase 3, just process one hit to Pilot compartment as an example
  # Full implementation would process all 6 hits
  return ('Pilot Compartment (Walking Hits)', 'P-2');
}

sub handle_walking_hits_b {
  my $self = shift;

  # Walking hits B: 2 hits each wing
  $self->smart_buffer("Walking hits across wings - multiple wing hits!");

  # For now, treat as superficial
  return ('Wings (Walking Hits)', 'P-1');
}

sub _replace_dead_crew_members {
  my $self = shift;

  my $crew = $self->save->crew;
  return unless $crew;

  my @all_crew = $crew->get_all_crew();
  my $replacements_made = 0;

  foreach my $member (@all_crew) {
    next unless $member;

    # Check if crew member is dead (has KIA or other final disposition)
    if ($member->has_final_disposition && defined $member->final_disposition) {
      my $position = $member->position;
      my $old_name = $member->name;
      my $disposition = $member->final_disposition;

      $self->devel("Replacing $disposition crew member: $old_name ($position)");

      # Replace with new crew member
      my $new_member = $crew->replace_crew_member($position);
      if ($new_member) {
        $self->buffer_success("$old_name ($disposition) has been replaced by " . $new_member->name . " as $position");
        $replacements_made++;
      }
    }
  }

  if ($replacements_made > 0) {
    $self->devel("Replaced $replacements_made dead crew member(s)");
    # Update the save data with the new crew
    $self->save->save->{crew} = $crew->to_hash();
  }

  return $replacements_made;
}

__PACKAGE__->meta->make_immutable;
1;