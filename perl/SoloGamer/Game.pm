package SoloGamer::Game;

use v5.42;

use File::Basename;
use Carp;
use Module::Runtime qw(require_module);

use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;
use SoloGamer::TableFactory;

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

has 'input_file' => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'input_file',
  default  => '',
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

sub new_game {
  my ($class, %options) = @_;
  
  my $game_name = $options{name} || 'QotS';
  
  # Map game names to their implementation classes
  my %game_classes = (
    'QotS' => 'SoloGamer::QotS::Game',
  );
  
  my $game_class = $game_classes{$game_name} // 'QotS';
  
  # Dynamically load the game class
  eval {
    require_module($game_class);
  } or croak "Failed to load game class $game_class: $@";
  
  return $game_class->new(%options);
}

sub substitute_variables {
  my ($self, $text) = @_;
  
  # Base implementation - subclasses can override to add specific substitutions
  return $text;
}

sub smart_buffer {
  my ($self, $text) = @_;
  
  return unless defined $text && length $text;
  
  # Apply variable substitution first
  $text = $self->substitute_variables($text);
  
  # Generic buffering logic - subclasses can override for game-specific patterns
  if ($text =~ /^Rolling for/i) {
    $self->buffer_roll($text);
  } elsif ($text =~ /^Welcome to/i) {
    $self->buffer_header($text, 40);
  } else {
    $self->buffer($text);
  }
  
  return;
}

sub _build_save {
  my $self = shift;
  
  my $save = SoloGamer::SaveGame->initialize( save_file  => $self->save_file,
                                              verbose    => $self->{'verbose'},
                                              automated  => $self->automated,
                                              input_file => $self->input_file,
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
    # Subclasses can implement zone_process for game-specific zone handling
    if (defined $do_action && $do_action eq 'zone_process') {
      if ($self->can('zone_process')) {
        $self->zone_process();
      }
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
  
  # Display detailed roll information if available
  if ($self->tables->{$table}->can('get_last_roll_details')) {
    my $roll_details = $self->tables->{$table}->get_last_roll_details();
    if ($roll_details) {
      $self->buffer_roll_details(
        $roll_details->{raw_result},
        $roll_details->{individual_rolls},
        $roll_details->{roll_type},
        $roll_details->{modifiers},
        $roll_details->{final_result}
      );
    }
  }
  
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

sub run_game {
  my $self = shift;

  $self->devel("In run_game");
  
  # Basic game flow - subclasses can override for specific game logic
  $self->do_flow('FLOW-start');
  $self->print_output;

  $self->save->save_game;
  return;
}
__PACKAGE__->meta->make_immutable;
1;
