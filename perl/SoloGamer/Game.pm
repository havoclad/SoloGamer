package SoloGamer::Game;

use v5.42;

use File::Basename;
use Carp;
use Module::Runtime qw(require_module);
use List::Util qw(first);

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
  if ($text =~ /^Rolling for/ix) {
    $self->buffer_roll($text);
  } elsif ($text =~ /^Welcome to/ix) {
    $self->buffer_header($text, 40);
  } else {
    $self->buffer($text);
  }

  return;
}

sub _build_save {
  my $self = shift;
  
  my $save = SoloGamer::SaveGame->initialize( save_file  => $self->save_file,
                                              verbose    => $self->{verbose},
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

sub do_loop {
  my $self       = shift;
  my $hr         = shift; # Whatever hash we're looping on
  my $action     = shift;
  my $reverse    = shift; # normal is low to high numerically
  my $do_action  = shift; # What to do in each zone (e.g., "zone_process")

  my $path = '';
  my @keys;
  if ($reverse) { # Travelling home
    @keys = sort { $b <=> $a } keys $hr->%*;
    $path = 'i';
  } else {        # Outbound
    @keys = sort { $a <=> $b } keys $hr->%*;
    $path = 'o';
  }

  my $total_zones = scalar @keys;
  my $current = 0;
  
  foreach my $i (@keys) {
    $current++;
    $self->smart_buffer( "$action $i");
    if ($action =~ /Moving to zone/i && $total_zones > 1) {
      $self->buffer_progress($current, $total_zones, '', 10);
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
    my $modifier_scope = $note->{scope};
    next unless $modifier_scope eq 'global' or $modifier_scope eq $scope_in;
    
    push @applied_modifiers, {
      modifier => $note->{modifier},
      why      => $note->{why}
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
      $self->buffer_roll_details($roll_details);
    }
  }
  
  if (defined $roll and exists $roll->{notes}) {
    my @preview_modifiers;
    
    foreach my $note ($roll->{notes}->@*) {
      # Handle both string notes and modifier object notes
      if (ref($note) ne 'HASH') {
        # It's a simple string note, skip modifier processing
        $self->devel("Note: $note");
        next;
      }
      
      my $modifier  = $note->{modifier};
      my $mod_table = $note->{table};
      my $why       = $note->{why};
      my $scope     = $note->{scope} || 'global';
      my $stack     = $note->{stack} || 1;

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

# Dispatch table for flow types
my %FLOW_TYPE_HANDLERS = (
  'choosemax'       => '_handle_choosemax_flow',
  'table'           => '_handle_table_flow',
  'loop'            => '_handle_loop_flow',
  'flow'            => '_handle_flow_flow',
  'process_wounds'  => '_handle_process_wounds_flow',
);

sub do_flow {
  my $self = shift;
  my $table_name = shift;

  while (my $next_flow = $self->tables->{$table_name}->get_next) {
    my $buffer_save = $self->get_buffer_size;
    my $post = exists $next_flow->{post} ? $next_flow->{post} : '';
    
    # Handle pre-message if it exists
    if (exists $next_flow->{pre}) {
      $self->_process_pre_message($next_flow);
    }
    
    # Process flow type using dispatch table
    if (exists $next_flow->{type}) {
      my $type = $next_flow->{type};
      my $handler = $FLOW_TYPE_HANDLERS{$type};
      
      if ($handler) {
        $self->$handler($next_flow, $buffer_save, $post);
      } else {
        croak "Unknown flow type: $type";
      }
    }
    
    $self->devel('\nEnd flow step\n');
  }
  $self->print_output;
  return;
}

# Process and potentially enhance pre-messages
sub _process_pre_message {
  my ($self, $next_flow) = @_;
  
  # Check if this is a 'Rolling for' message that needs enhancement
  if (exists $next_flow->{type} && $next_flow->{pre} =~ /^Rolling for/ix) {
    my $enhanced_message = $self->_enhance_rolling_message($next_flow);
    $self->smart_buffer($enhanced_message);
  } else {
    $self->smart_buffer($next_flow->{pre});
  }
  return;
}

# Enhance 'Rolling for' messages with table information
sub _enhance_rolling_message {
  my ($self, $next_flow) = @_;
  my $type = $next_flow->{type};
  my $pre = $next_flow->{pre};
  
  if ($type eq 'table' && exists $next_flow->{Table}) {
    return $self->_enhance_table_message($next_flow, $pre);
  }
  elsif ($type eq 'choosemax' && exists $next_flow->{choices}) {
    return $self->_enhance_choosemax_message($next_flow, $pre);
  }
  
  return $pre;
}

# Enhance message for table type flows
sub _enhance_table_message {
  my ($self, $next_flow, $pre) = @_;
  my $next_table_name = $next_flow->{Table};
  my $table_obj = $self->tables->{$next_table_name};
  
  if ($table_obj && ref($table_obj)) {
    my $rolltype = $self->_get_rolltype($table_obj);
    return "${pre}${rolltype} on table $next_table_name";
  }
  
  return $pre;
}

# Enhance message for choosemax type flows
sub _enhance_choosemax_message {
  my ($self, $next_flow, $pre) = @_;
  my $choice = $next_flow->{variable};
  my $mission_value = $self->_get_mission_value($choice);
  my $table_item = first { $mission_value <= $_->{max} } $next_flow->{choices}->@*;
  my $table = $table_item->{Table};

  return "$pre on table $table";
}

# Get rolltype from table object if available
sub _get_rolltype {
  my ($self, $table_obj) = @_;
  
  if ($table_obj->isa('SoloGamer::RollTable') && $table_obj->can('rolltype')) {
    my $rolltype = $table_obj->rolltype || '';
    return $rolltype ? " $rolltype" : '';
  }
  
  return '';
}

# Get mission value from save or default to global mission
sub _get_mission_value {
  my ($self, $choice) = @_;
  my $mission_value = $self->save->get_from_current_mission($choice);
  
  if (!defined $mission_value) {
    $mission_value = $self->save->mission;
    $self->devel("Using global mission number: $mission_value");
  }
  
  return $mission_value;
}

# Handler for choosemax flow type
sub _handle_choosemax_flow {  ## no critic (ProhibitUnusedPrivateSubroutines)
  my ($self, $next_flow, $buffer_save, $post) = @_;

  $self->save->add_save('Mission', $self->save->mission);
  my $choice = $next_flow->{variable};
  my $mission_value = $self->_get_mission_value($choice);
  my $table_item = first { $mission_value <= $_->{max} } $next_flow->{choices}->@*;
  my $table = $table_item->{Table};

  my $roll = $self->do_roll($table);
  $self->handle_output('Target', $roll->{Target});
  $self->handle_output('Type', $roll->{Type});
  return;
}

# Handler for table flow type
sub _handle_table_flow {  ## no critic (ProhibitUnusedPrivateSubroutines)
  my ($self, $next_flow, $buffer_save, $post) = @_;
  
  my $table = $next_flow->{Table};
  my $roll = $self->do_roll($table);
  
  if (not defined $roll) {
    $self->flush_to($buffer_save);
    return;
  }
  
  my $determines = $self->tables->{$table}->determines;
  my $output_value = $roll->{$determines};
  
  # Add weather icon if available
  if ($determines eq 'weather' && exists $roll->{icon}) {
    $output_value .= ' ' . $roll->{icon};
  }
  
  $self->handle_output($determines, $output_value, $post);
  return;
}

# Handler for loop flow type
sub _handle_loop_flow {  ## no critic (ProhibitUnusedPrivateSubroutines)
  my ($self, $next_flow, $buffer_save, $post) = @_;
  
  my $loop_table = $next_flow->{loop_table};
  my $loop_variable = $next_flow->{loop_variable};
  my $reverse = exists $next_flow->{reverse} ? 1 : 0;
  my $do_action = exists $next_flow->{do} ? $next_flow->{do} : undef;
  my $target_city = $self->save->get_from_current_mission('Target');
  
  $self->do_loop(
    $self->tables->{$loop_table}->{data}->{'target city'}->{$target_city}->{$loop_variable},
    'Moving to zone: ',
    $reverse,
    $do_action,
  );
  return;
}

# Handler for flow flow type (nested flow)
sub _handle_flow_flow {  ## no critic (ProhibitUnusedPrivateSubroutines)
  my ($self, $next_flow, $buffer_save, $post) = @_;

  my $flow_table = $next_flow->{flow_table};
  $self->do_flow($flow_table);
  return;
}

sub _handle_process_wounds_flow {  ## no critic (ProhibitUnusedPrivateSubroutines)
  my ($self, $next_flow, $buffer_save, $post) = @_;

  # Process serious wounds for survival per BL-4 subnote b)
  if ($self->save->crew) {
    my $processed = $self->save->crew->process_serious_wounds($self);
    if ($processed > 0) {
      $self->devel("Processed $processed serious wound(s) post-landing");
      # Update save with crew changes
      $self->save->save->{crew} = $self->save->crew->to_hash();
    }
    else {
      # No wounds to process - rollback the pre-message
      $self->flush_to($buffer_save);
    }
  }
  return;
}

sub roll_dice {
  my ($self, $dice_spec) = @_;

  # Parse dice specification (e.g., "1d6", "2d6")
  if ($dice_spec =~ /^(\d+)d(\d+)$/x) {
    my $num_dice = $1;
    my $die_size = $2;
    my $total = 0;

    for (1 .. $num_dice) {
      $total += int(rand($die_size) + 1);
    }

    return $total;
  }

  croak "Invalid dice specification: $dice_spec";
}

sub run_game {
  my $self = shift;

  $self->devel('In run_game');

  # Basic game flow - subclasses can override for specific game logic
  $self->do_flow('FLOW-start');
  $self->print_output;

  $self->save->save_game;
  return;
}
__PACKAGE__->meta->make_immutable;
1;
