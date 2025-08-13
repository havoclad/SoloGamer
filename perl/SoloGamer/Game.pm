package SoloGamer::Game;

use strict;
use v5.20;

use File::Basename;
use Carp;

use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;
use SoloGamer::TableFactory;
use SoloGamer::QotS::CombatState;

extends 'SoloGamer::Base';

with 'BufferedOutput';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'save'      => (
  is            => 'ro',
  #isa           => 'HashRef',
  builder       => '_build_save',
  lazy          => 1,
);

has 'name' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'name',
);

has 'source_data' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  required => 1,
  builder  => '_build_source_data',
);

has 'source' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  required => 1,
  builder  => '_build_source',
);

has 'tables' => (
  is       => 'ro',
  isa      => 'HashRef',
  lazy     => 1,
  required => 1,
  builder  => '_build_load_data_tables',
);

has 'automated' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'automated',
);

has 'use_color' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'use_color',
  default  => 1,
);

has 'zone' => (
  is       => 'rw',
  isa      => 'Str',
  init_arg => 1,
);

sub BUILD {
  my $self = shift;
  
  $self->formatter->use_color($self->use_color);
  
  return;
}

sub substitute_variables {
  my ($self, $text) = @_;
  
  return $text unless defined $text && length $text;
  
  # Substitute plane name variable
  if ($text =~ /\$plane_name/) {
    my $plane_name = $self->save->get_plane_name();
    $text =~ s/\$plane_name/$plane_name/g;
  }
  
  return $text;
}

sub smart_buffer {
  my ($self, $text) = @_;
  
  return unless defined $text && length $text;
  
  # Apply variable substitution first
  $text = $self->substitute_variables($text);
  
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
}

sub _build_save {
  my $self = shift;
  
  my $save = SoloGamer::SaveGame->initialize( save_file => $self->save_file,
                                              verbose   => $self->{'verbose'},
                                              automated => $self->automated,
                                            );
  $save->load_save;
  return $save;
}

sub _build_source {
  my $self = shift;
  return '/games/' . $self->name . '/';
}

sub _build_source_data {
  my $self = shift;
  return $self->source . 'data';
}

sub _build_load_data_tables {
  my $self = shift;

  my $h = {};
  my $dir = $self->source_data;
  $self->devel("looking for $dir");
  my $factory = SoloGamer::TableFactory-> new (
                                            verbose   => $self->verbose,
                                            automated => $self->automated,
                                           );
  foreach my $table (glob("$dir/*")) {
    $self->devel("loading $table");
    my ($filename, $dirs, $suffix) = fileparse($table, '.json');
    $h->{$filename} = $factory->new_table( $table);
  }
  return $h;
}

# Intent is to return the first item in an array that is less than the input
sub do_max {
  my $self = shift;
  my $variable = shift;
  my $choices = shift;

  # Ensure numeric comparison
  $variable = int($variable) if defined $variable;
  
  foreach my $item (@$choices) {
    my $max = int($item->{'max'});
    return $item->{'Table'} if $variable <= $max;
  }
  croak "Didn't find a max that matched $variable";
}

sub do_loop {
  my $self       = shift;
  my $hr         = shift;  # Whatever hash we're looping on
  my $action     = shift;
  my $reverse    = shift; # normal is low to high numerically
  my $do_action  = shift; # What to do in each zone (e.g., "zone_process")

  my $path = "";
  my @keys;
  if ($reverse) { # Travelling home
    @keys = sort { $b <=> $a } keys $hr->%*;
    $path = "i";
  } else {        # Outbound
    @keys = sort { $a <=> $b } keys $hr->%*;
    $path = "o";
  }

  my $total_zones = scalar @keys;
  my $current = 0;
  
  foreach my $i (@keys) {
    $current++;
    # Add separator before moving to each zone
    if ($action =~ /Moving to zone/i) {
      $self->buffer_zone_separator();
    }
    $self->smart_buffer( "$action $i");
    if ($action =~ /Moving to zone/i && $total_zones > 1) {
      $self->buffer_progress($current, $total_zones, "", 10);
    }
    $self->zone("$i$path");
    
    # Process the zone if action specified
    if (defined $do_action && $do_action eq 'zone_process') {
      $self->zone_process();
    }
  }
  return;
}

sub handle_output{
  my $self = shift;
  my $key = shift;
  my $value = shift;
  my $text = shift;

  $self->save->add_save($key, $value);
  if ( defined $text and length $text ) {
    $self->devel("In handle output with key: $key, value: $value, and text: $text --");
    $text =~ s{ <1>   }{ $value }xmse;
    $text =~ s{ \(s\) }{ $value == 1? '' : 's'}xmse;
    $text = $self->substitute_variables($text);
    $self->smart_buffer($text);
  } else {
    $self->devel("In handle output with key: $key, value: $value");
    $self->smart_buffer("$key: $value");
  }
  return;
}

sub display_applied_modifiers {
  my $self = shift;
  my $table_name = shift;
  
  return unless exists $self->tables->{$table_name};
  
  my $table_obj = $self->tables->{$table_name};
  my $scope_in = $self->zone;
  
  # Get total modifiers to see if we need to display anything
  my $total_modifiers = $table_obj->get_total_modifiers($scope_in);
  return if $total_modifiers == 0;
  
  my @applied_modifiers;
  my $scope = $table_obj->scope;
  
  # Add conditional roll modifier if any
  my $conditional_modifier = $table_obj->evaluate_roll_modifier();
  if ($conditional_modifier != 0) {
    push @applied_modifiers, {
      modifier => $conditional_modifier,
      why      => 'conditional roll modifier'
    };
  }
  
  # Add explicit modifiers
  foreach my $note (@{$table_obj->modifiers}) {
    my $modifier_scope = $note->{'scope'};
    next unless $modifier_scope eq 'global' or $modifier_scope eq $scope_in;
    
    push @applied_modifiers, {
      modifier => $note->{'modifier'},
      why      => $note->{'why'}
    };
  }
  
  if (@applied_modifiers) {
    $self->buffer_modifier_applied(\@applied_modifiers);
  }
  
  return;
}

sub do_roll {
  my $self  = shift;
  my $table = shift;

  # Display applied modifiers before rolling if any exist
  $self->display_applied_modifiers($table);

  my $roll = $self->tables->{$table}->roll($self->zone);
  if (defined $roll and exists $roll->{'notes'}) {
    my @preview_modifiers;
    
    foreach my $note ($roll->{'notes'}->@*) {
      # Handle both string notes and modifier object notes
      if (ref($note) ne 'HASH') {
        # It's a simple string note, skip modifier processing
        $self->devel("Note: $note");
        next;
      }
      
      my $modifier  = $note->{'modifier'};
      my $mod_table = $note->{'table'};
      my $why       = $note->{'why'};
      my $scope     = $note->{'scope'} || 'global';
      my $stack     = $note->{'stack'} || 1;

      if ($scope eq 'zone' ) {
        $scope = $self->zone;
      };
      $self->devel("$why results in a $modifier to table $mod_table for scope: $scope");

      exists $self->tables->{$mod_table} 
        and $self->tables->{$mod_table}->add_modifier( { modifier => $modifier,
                                                         why      => $why, 
                                                         from_table    => $table,
                                                         scope    => $scope,
                                                         stack    => $stack
                                                       } );
      
      # Collect modifier info for preview display
      if (exists $self->tables->{$mod_table}) {
        my $table_title = $self->tables->{$mod_table}->title || $mod_table;
        push @preview_modifiers, {
          table    => $mod_table,
          title    => $table_title,
          modifier => $modifier,
          why      => $why
        };
      }
    }
    
    # Display modifier preview if any modifiers were added
    if (@preview_modifiers) {
      $self->buffer_modifier_preview(\@preview_modifiers);
    }
  }
  return $roll;
}

sub do_flow {
  my $self = shift;
  my $table_name = shift;

  while (my $next_flow = $self->tables->{$table_name}->get_next) {
    my $buffer_save = $self->get_buffer_size;
    my $post = "";
    if (exists $next_flow->{'post'}) {
      $post = $next_flow->{'post'};
    }
    if (exists $next_flow->{'pre'}) {
      # Check if this is a table type flow to enhance the pre message
      if (exists $next_flow->{'type'} && $next_flow->{'pre'} =~ /^Rolling for/i) {
        my $enhanced = 0;
        
        # Handle direct table references
        if ($next_flow->{'type'} eq 'table' && exists $next_flow->{'Table'}) {
          my $table_name = $next_flow->{'Table'};
          my $table_obj = $self->tables->{$table_name};
          if ($table_obj && ref($table_obj)) {
            # Try to get rolltype if it's a RollTable
            my $rolltype = '';
            if ($table_obj->isa('SoloGamer::RollTable') && $table_obj->can('rolltype')) {
              $rolltype = $table_obj->rolltype || '';
              $rolltype = " $rolltype" if $rolltype;
            }
            my $enhanced_pre = $next_flow->{'pre'} . $rolltype . " on table $table_name";
            $self->smart_buffer($enhanced_pre);
            $enhanced = 1;
          }
        }
        # Handle choosemax which eventually calls a table
        elsif ($next_flow->{'type'} eq 'choosemax' && exists $next_flow->{'choices'}) {
          # For choosemax, determine which table will be used and show it in the pre message
          my $choice = $next_flow->{'variable'};
          my $mission_value = $self->save->get_from_current_mission($choice);
          # If no mission value from current mission data, use the global mission number
          if (!defined $mission_value) {
            $mission_value = $self->save->mission;
          }
          my $table = $self->do_max($mission_value, $next_flow->{'choices'});
          my $enhanced_pre = $next_flow->{'pre'} . " on table $table";
          $self->smart_buffer($enhanced_pre);
          $enhanced = 1;
        }
        
        if (!$enhanced) {
          $self->smart_buffer($next_flow->{'pre'});
        }
      } else {
        $self->smart_buffer($next_flow->{'pre'});
        # Add separator after takeoff message
        if ($next_flow->{'pre'} =~ /took off/i) {
          $self->buffer_zone_separator();
        }
      }
    }
    if (exists $next_flow->{'type'}) {
      if ($next_flow->{'type'} eq 'choosemax') {
        $self->save->add_save('Mission', $self->save->mission);
        my $choice = $next_flow->{'variable'};
        my $mission_value = $self->save->get_from_current_mission($choice);
        # If no mission value from current mission data, use the global mission number
        if (!defined $mission_value) {
          $mission_value = $self->save->mission;
          $self->devel("Using global mission number: $mission_value");
        }
        my $table = $self->do_max($mission_value, $next_flow->{'choices'});
        
        my $roll = $self->do_roll($table);
        $self->handle_output('Target', $roll->{'Target'});
        $self->handle_output('Type', $roll->{'Type'});
      } elsif ($next_flow->{'type'} eq 'table') {
        my $table = $next_flow->{'Table'};
        my $roll = $self->do_roll($table);
        if (not defined $roll) {
          $self->flush_to($buffer_save);
          next;
        }
        my $determines = $self->tables->{$table}->determines;
        # Pass icon along with weather value if available
        my $icon = '';
        if ($determines eq 'weather' && exists $roll->{'icon'}) {
          $icon = ' ' . $roll->{'icon'};
        }
        $self->handle_output($determines, $roll->{$determines} . $icon, $post);
      } elsif ($next_flow->{'type'} eq 'loop') {
        my $loop_table = $next_flow->{'loop_table'};
        my $loop_variable = $next_flow->{'loop_variable'};
        my $reverse = exists $next_flow->{'reverse'} ? 1 : 0;
        my $do_action = exists $next_flow->{'do'} ? $next_flow->{'do'} : undef;
        my $target_city = $self->save->get_from_current_mission('Target');
        $self->do_loop( $self->tables->{$loop_table}->{'data'}->{'target city'}->{$target_city}->{$loop_variable},
                        "Moving to zone: ",
                        $reverse,
                        $do_action,
                      );
      } elsif ($next_flow->{'type'} eq 'flow') {
        my $flow_table = $next_flow->{'flow_table'};
        $self->do_flow($flow_table);
      } else {
        croak "Unknown flow type: ", $next_flow->{'type'};
      }
    }
    $self->devel("\nEnd flow step\n");
  }
  $self->print_output;
  return;
}


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

sub run_game {
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
}
__PACKAGE__->meta->make_immutable;
1;
