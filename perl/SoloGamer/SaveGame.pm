package SoloGamer::SaveGame;

use v5.42;

use File::Copy;
use File::Slurp;
use Carp;

use MooseX::Singleton;
use Mojo::JSON qw ( encode_json decode_json );
use namespace::autoclean;

use SoloGamer::TypeLibrary qw / PositiveInt /;
use SoloGamer::QotS::PlaneNamer;
use SoloGamer::QotS::Crew;
use SoloGamer::QotS::AircraftState;
use SoloGamer::QotS::CombatState;

with 'Logger';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
  default       => '',
);

has 'save'    => (
  is          => 'rw',
  isa         => 'HashRef',
  lazy        => 1,
  default     => sub { {} },
);

has 'mission' => (
  is       => 'rw',
  isa      => PositiveInt,
);

has 'automated' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'automated',
  default  => 0,
);

has 'input_file' => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'input_file',
  default  => '',
);

has 'crew' => (
  is      => 'rw',
  isa     => 'Maybe[SoloGamer::QotS::Crew]',
  lazy    => 1,
  builder => '_build_crew',
);

has 'aircraft_state' => (
  is      => 'rw',
  isa     => 'Maybe[SoloGamer::QotS::AircraftState]',
  lazy    => 1,
  builder => '_build_aircraft_state',
);

has 'combat_state' => (
  is      => 'rw',
  isa     => 'Maybe[SoloGamer::QotS::CombatState]',
  lazy    => 1,
  builder => '_build_combat_state',
  clearer => 'clear_combat_state',
);

sub load_save {
  my $self = shift;

  my $save_to_load = $self->save_file;

  my $mission = 1;
  if ($save_to_load && -e $save_to_load) {
    $self->devel("Trying to load $save_to_load");
    my $json = read_file($save_to_load);
    my $decoded = decode_json($json);
    $self->save($decoded) or croak $!;
    
    # Load crew if it exists
    if (exists $self->save->{crew}) {
      $self->crew(SoloGamer::QotS::Crew->from_hash($self->save->{crew}, $self->automated));
    }
    
    # Load aircraft state if it exists
    if (exists $self->save->{aircraft_state}) {
      $self->aircraft_state(SoloGamer::QotS::AircraftState->from_hash($self->save->{aircraft_state}));
    }
    
    # Check if mission exists and is an array
    if (exists $self->save->{mission} && ref($self->save->{mission}) eq 'ARRAY') {
      my $last_mission = $self->save->{mission}->$#* + 1;
      $self->devel("Last mission was: $last_mission");
      $mission = $last_mission + 1;
    } else {
      $self->devel('No mission array found in save data');
    }
  } else {
    if ($save_to_load eq '') {
      $self->devel('No save file, use --save_file on command line to set');
    } else {
      $self->devel("No save file found at $save_to_load");
    }
    
    # Create new save with plane name selection
    my $plane_namer = SoloGamer::QotS::PlaneNamer->new(
      automated  => $self->automated,
      input_file => $self->input_file,
    );
    my $plane_name = $plane_namer->prompt_for_plane_name();
    
    # Create new crew
    my $crew = SoloGamer::QotS::Crew->new(
      automated  => $self->automated,
      input_file => $self->input_file,
    );
    
    # Create new aircraft state
    my $aircraft = SoloGamer::QotS::AircraftState->new();
    
    my $temp = { 
      mission => [{}],
      plane_name => $plane_name,
      crew => $crew->to_hash(),
      aircraft_state => $aircraft->to_hash()
    };
    $self->save($temp);
    $self->crew($crew);
    $self->aircraft_state($aircraft);
  }
  $self->mission($mission);
  return $mission;

}

sub save_game {
  my $self = shift;

  # Update crew data in save before writing
  if ($self->crew) {
    $self->save->{crew} = $self->crew->to_hash();
  }
  
  # Update aircraft state in save before writing
  if ($self->aircraft_state) {
    $self->save->{aircraft_state} = $self->aircraft_state->to_hash();
  }

  if ($self->save_file) {
    $self->devel('Writing save file to ', $self->save_file);
    my $tmp_file = $self->save_file . '.tmp';
    open(my $fh, '>', $tmp_file) or croak "Can't open $tmp_file $!";
    print $fh encode_json($self->save) or croak('Can\'t write file at: ', $tmp_file, ' $!');
    close $fh;
    move($tmp_file, $self->save_file) or croak("Can't move $tmp_file to ", $self->save_file);
  } else {
    $self->devel('No save file to write');
  }
  return;
}

sub add_save {
  my $self     = shift;
  my $property = shift;
  my $value    = shift;

  $self->save->{mission}->[$self->mission-1]->{$property} = $value;
  return;
}

sub get_from_current_mission {
  my $self = shift;
  my $property = shift;

  $self->devel("Looking for $property in mission: ", $self->mission);
  return $self->save->{mission}->[$self->mission-1]->{$property};
}

sub get_plane_name {
  my $self = shift;
  
  return $self->save->{plane_name} || 'Unnamed B-17';
}

sub _build_crew {
  my $self = shift;
  
  if (exists $self->save->{crew}) {
    return SoloGamer::QotS::Crew->from_hash($self->save->{crew}, $self->automated);
  }
  
  return;
}

sub get_crew {
  my $self = shift;
  return $self->crew;
}

sub update_crew_after_mission {
  my $self = shift;

  if ($self->crew) {
    $self->crew->add_mission_for_active();
    $self->save->{crew} = $self->crew->to_hash();
  }
  return;
}

sub display_mission_record {
  my $self = shift;

  # Get and validate mission history
  my @completed_missions = $self->_get_completed_missions();
  return "No completed missions yet.\n" unless @completed_missions;

  # Build the mission record display
  my $formatter = SoloGamer::Formatter->new();
  my $header = $formatter->box_header("B-17 COMPOSITE MISSION RECORD", 140);
  my $output = "\n$header\n\n";

  # Single unified table with all crew positions
  $output .= $self->_format_unified_mission_table(\@completed_missions);

  $output .= "=" x 140 . "\n";

  return $output;
}

sub _get_completed_missions {
  my $self = shift;

  my $missions = $self->save->{mission};
  return () unless ($missions && ref($missions) eq 'ARRAY');

  # Filter out empty missions (mission 0 placeholder)
  return grep { defined $_->{Mission} && $_->{Mission} > 0 } @$missions;
}

sub _format_unified_mission_table {
  my ($self, $missions) = @_;

  my $output = "";

  # Table header - all crew positions in one line
  $output .= sprintf("%-3s %-12s %-18s %-6s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n",
    "MSN", "B-17 NAME", "TARGET", "BOMB%",
    "BOMBARDIER", "NAVIGATOR", "PILOT", "CO-PILOT",
    "ENGINEER", "RADIO OP", "BALL", "PORT WAIST", "STBD WAIST", "TAIL");

  # Rank sub-header
  $output .= sprintf("%-3s %-12s %-18s %-6s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n",
    "", "", "", "",
    "Lieut.", "Lieut.", "Capt.", "Lieut.",
    "Tech Sgt.", "Sgt.", "Sgt.", "Sgt.", "Sgt.", "Sgt.");

  $output .= "=" x 140 . "\n";

  # Display each mission
  foreach my $mission_data (@$missions) {
    $output .= $self->_format_unified_mission_row($mission_data);
  }

  return $output;
}

sub _format_unified_mission_row {
  my ($self, $mission_data) = @_;

  my $mission_num = $mission_data->{Mission} || '?';
  my $plane_name = $self->get_plane_name || 'Unknown';
  my $target = $self->_format_target($mission_data, 18);

  # Format bomb percentage: show actual % if available, otherwise show On/Off status
  my $bomb_pct = $mission_data->{bombing_accuracy} || '0';
  if ($bomb_pct =~ /^\d+$/xms) {
    # If it's just a number, add % sign
    $bomb_pct = $bomb_pct . '%';
  }

  # Get all crew names from historical mission data (trimmed to 12 chars)
  my $bombardier = $self->_trim_name($mission_data->{crew_bombardier}, 12);
  my $navigator = $self->_trim_name($mission_data->{crew_navigator}, 12);
  my $pilot = $self->_trim_name($mission_data->{crew_pilot}, 12);
  my $copilot = $self->_trim_name($mission_data->{crew_copilot}, 12);
  my $engineer = $self->_trim_name($mission_data->{crew_engineer}, 12);
  my $radio_op = $self->_trim_name($mission_data->{crew_radio_operator}, 12);
  my $ball = $self->_trim_name($mission_data->{crew_ball_gunner}, 12);
  my $port = $self->_trim_name($mission_data->{crew_port_waist_gunner}, 12);
  my $stbd = $self->_trim_name($mission_data->{crew_starboard_waist_gunner}, 12);
  my $tail = $self->_trim_name($mission_data->{crew_tail_gunner}, 12);

  # Trim plane name to fit
  $plane_name = substr($plane_name, 0, 11) if length($plane_name) > 12;

  # Trim bomb percentage to fit
  $bomb_pct = substr($bomb_pct, 0, 5) if length($bomb_pct) > 6;

  return sprintf("%-3d %-12s %-18s %-6s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n",
    $mission_num, $plane_name, $target, $bomb_pct,
    $bombardier, $navigator, $pilot, $copilot,
    $engineer, $radio_op, $ball, $port, $stbd, $tail);
}

sub _format_target {
  my ($self, $mission_data, $max_length) = @_;

  $max_length = $max_length || 20;

  my $target = ($mission_data->{Target} || 'Unknown') . ' (' . ($mission_data->{Type} || '?') . ')';

  # Trim target if too long
  if (length($target) > $max_length) {
    $target = substr($target, 0, $max_length - 3) . '...';
  }

  return $target;
}

sub _trim_name {
  my ($self, $name, $max_length) = @_;

  $max_length = $max_length || 15;
  $name = $name || 'Unknown';

  # Trim name if too long
  if (length($name) > $max_length) {
    $name = substr($name, 0, $max_length - 1);
  }

  return $name;
}

sub _build_aircraft_state {
  my $self = shift;
  
  if (exists $self->save->{aircraft_state}) {
    return SoloGamer::QotS::AircraftState->from_hash($self->save->{aircraft_state});
  }
  
  return SoloGamer::QotS::AircraftState->new();
}

sub _build_combat_state {
  my $self = shift;
  
  return SoloGamer::QotS::CombatState->new();
}

sub reset_combat_for_zone {
  my ($self, $zone) = @_;
  
  if ($self->combat_state) {
    $self->combat_state->reset_for_zone($zone);
  } else {
    $self->combat_state(SoloGamer::QotS::CombatState->new());
    $self->combat_state->zone($zone) if defined $zone;
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;
