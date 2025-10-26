package SoloGamer::SaveGame;

use v5.42;

use File::Copy;
use File::Slurp;
use Carp;
use IO::Prompter;

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

has '_input_fh' => (
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_input_fh',
  clearer  => '_clear_input_fh',
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
  my $is_autosave = $save_to_load && $save_to_load eq '/app/saves/automated.json';

  my $mission = 1;
  my $load_existing = $self->_should_load_existing_save($save_to_load, $is_autosave);

  if ($load_existing) {
    $mission = $self->_load_existing_save($save_to_load);
  } else {
    $self->_create_new_save($save_to_load);
  }

  $self->mission($mission);
  return $mission;
}

sub _should_load_existing_save {
  my ($self, $save_to_load, $is_autosave) = @_;

  return 0 unless $save_to_load && -e $save_to_load;

  # Not autosave or automated mode - always load
  if (!$is_autosave || $self->automated) {
    return 1;
  }

  # Interactive mode with autosave - ask user
  return $self->_prompt_for_autosave_choice($save_to_load);
}

sub _prompt_for_autosave_choice {
  my ($self, $save_to_load) = @_;

  say "\nFound existing autosave game.";

  my $response = $self->_get_autosave_response();

  if (defined $response && $response =~ /C/i) {
    return 1;
  } elsif (defined $response && $response =~ /N/i) {
    $self->devel("User chose to start new game, deleting autosave");
    unlink $save_to_load or $self->devel("Warning: Could not delete old autosave: $!");
    return 0;
  }

  # Default to continue
  return 1;
}

sub _get_autosave_response {
  my $self = shift;

  if ($self->input_file && $self->_input_fh) {
    say "[C]ontinue previous game or start [N]ew game?";
    my $response = readline($self->_input_fh);
    if (defined $response) {
      chomp $response;
      $self->devel("Read from input file: $response");
    }
    return $response;
  }

  return prompt 'Continue previous game or start New game?', -menu => ['Continue', 'New'], -keyletters, -single;
}

sub _load_existing_save {
  my ($self, $save_to_load) = @_;

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

  # Calculate next mission number
  my $mission = 1;
  if (exists $self->save->{mission} && ref($self->save->{mission}) eq 'ARRAY') {
    my $last_mission = $self->save->{mission}->$#* + 1;
    $self->devel("Last mission was: $last_mission");
    $mission = $last_mission + 1;
  } else {
    $self->devel('No mission array found in save data');
  }

  return $mission;
}

sub _create_new_save {
  my ($self, $save_to_load) = @_;

  if ($save_to_load eq '') {
    $self->devel('No save file, use --save_file on command line to set');
  } else {
    $self->devel("No save file found at $save_to_load or user chose to start new");
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

  return;
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

  # Build the mission table and get its width
  my ($table_content, $table_width) = $self->_format_unified_mission_table(\@completed_missions);

  # Build the mission record display with dynamic width
  my $formatter = SoloGamer::Formatter->new();
  my $header = $formatter->box_header("B-17 COMPOSITE MISSION RECORD", $table_width);
  my $output = "\n$header\n\n";

  # Add table content
  $output .= $table_content;

  # Add bottom separator
  $output .= "=" x $table_width . "\n";

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

  # First pass: collect all data and calculate column widths
  my @rows;
  my %max_widths = (
    msn => 3,
    plane => length("B-17 NAME"),
    target => length("TARGET"),
    bomb => length("BOMB%"),
    bombardier => length("BOMBARDIER"),
    navigator => length("NAVIGATOR"),
    pilot => length("PILOT"),
    copilot => length("CO-PILOT"),
    engineer => length("ENGINEER"),
    radio => length("RADIO OP"),
    ball => length("BALL"),
    port => length("PORT WAIST"),
    stbd => length("STBD WAIST"),
    tail => length("TAIL"),
  );

  # Collect data and track maximum widths
  foreach my $mission_data (@$missions) {
    my $row = $self->_extract_mission_data($mission_data);
    push @rows, $row;

    # Update maximum widths
    $max_widths{msn} = _max($max_widths{msn}, length($row->{msn}));
    $max_widths{plane} = _max($max_widths{plane}, length($row->{plane}));
    $max_widths{target} = _max($max_widths{target}, length($row->{target}));
    $max_widths{bomb} = _max($max_widths{bomb}, length($row->{bomb}));
    $max_widths{bombardier} = _max($max_widths{bombardier}, length($row->{bombardier}));
    $max_widths{navigator} = _max($max_widths{navigator}, length($row->{navigator}));
    $max_widths{pilot} = _max($max_widths{pilot}, length($row->{pilot}));
    $max_widths{copilot} = _max($max_widths{copilot}, length($row->{copilot}));
    $max_widths{engineer} = _max($max_widths{engineer}, length($row->{engineer}));
    $max_widths{radio} = _max($max_widths{radio}, length($row->{radio}));
    $max_widths{ball} = _max($max_widths{ball}, length($row->{ball}));
    $max_widths{port} = _max($max_widths{port}, length($row->{port}));
    $max_widths{stbd} = _max($max_widths{stbd}, length($row->{stbd}));
    $max_widths{tail} = _max($max_widths{tail}, length($row->{tail}));
  }

  # Also check rank sub-header widths
  $max_widths{bombardier} = _max($max_widths{bombardier}, length("Lieut."));
  $max_widths{navigator} = _max($max_widths{navigator}, length("Lieut."));
  $max_widths{pilot} = _max($max_widths{pilot}, length("Capt."));
  $max_widths{copilot} = _max($max_widths{copilot}, length("Lieut."));
  $max_widths{engineer} = _max($max_widths{engineer}, length("Tech Sgt."));
  $max_widths{radio} = _max($max_widths{radio}, length("Sgt."));
  $max_widths{ball} = _max($max_widths{ball}, length("Sgt."));
  $max_widths{port} = _max($max_widths{port}, length("Sgt."));
  $max_widths{stbd} = _max($max_widths{stbd}, length("Sgt."));
  $max_widths{tail} = _max($max_widths{tail}, length("Sgt."));

  # Add padding (2 spaces between columns)
  foreach my $key (keys %max_widths) {
    $max_widths{$key} += 2;
  }

  # Build format string
  my $fmt = "%-$max_widths{msn}s%-$max_widths{plane}s%-$max_widths{target}s%-$max_widths{bomb}s" .
            "%-$max_widths{bombardier}s%-$max_widths{navigator}s%-$max_widths{pilot}s%-$max_widths{copilot}s" .
            "%-$max_widths{engineer}s%-$max_widths{radio}s%-$max_widths{ball}s%-$max_widths{port}s" .
            "%-$max_widths{stbd}s%-$max_widths{tail}s\n";

  # Calculate total width
  my $total_width = 0;
  foreach my $width (values %max_widths) {
    $total_width += $width;
  }

  # Build output
  my $output = "";

  # Table header
  $output .= sprintf($fmt,
    "MSN", "B-17 NAME", "TARGET", "BOMB%",
    "BOMBARDIER", "NAVIGATOR", "PILOT", "CO-PILOT",
    "ENGINEER", "RADIO OP", "BALL", "PORT WAIST", "STBD WAIST", "TAIL");

  # Rank sub-header
  $output .= sprintf($fmt,
    "", "", "", "",
    "Lieut.", "Lieut.", "Capt.", "Lieut.",
    "Tech Sgt.", "Sgt.", "Sgt.", "Sgt.", "Sgt.", "Sgt.");

  $output .= "=" x $total_width . "\n";

  # Display each mission
  foreach my $row (@rows) {
    $output .= sprintf($fmt,
      $row->{msn}, $row->{plane}, $row->{target}, $row->{bomb},
      $row->{bombardier}, $row->{navigator}, $row->{pilot}, $row->{copilot},
      $row->{engineer}, $row->{radio}, $row->{ball}, $row->{port},
      $row->{stbd}, $row->{tail});
  }

  return ($output, $total_width);
}

sub _max {
  my ($a, $b) = @_;
  return $a > $b ? $a : $b;
}

sub _extract_mission_data {
  my ($self, $mission_data) = @_;

  my $mission_num = $mission_data->{Mission} || '?';
  my $plane_name = $self->get_plane_name || 'Unknown';
  my $target = ($mission_data->{Target} || 'Unknown') . ' (' . ($mission_data->{Type} || '?') . ')';

  # Format bomb percentage
  my $bomb_pct = $mission_data->{bombing_accuracy} || '0';
  if ($bomb_pct =~ /^\d+$/xms) {
    $bomb_pct = $bomb_pct . '%';
  }

  return {
    msn => $mission_num,
    plane => $plane_name,
    target => $target,
    bomb => $bomb_pct,
    bombardier => $mission_data->{crew_bombardier} || 'Unknown',
    navigator => $mission_data->{crew_navigator} || 'Unknown',
    pilot => $mission_data->{crew_pilot} || 'Unknown',
    copilot => $mission_data->{crew_copilot} || 'Unknown',
    engineer => $mission_data->{crew_engineer} || 'Unknown',
    radio => $mission_data->{crew_radio_operator} || 'Unknown',
    ball => $mission_data->{crew_ball_gunner} || 'Unknown',
    port => $mission_data->{crew_port_waist_gunner} || 'Unknown',
    stbd => $mission_data->{crew_starboard_waist_gunner} || 'Unknown',
    tail => $mission_data->{crew_tail_gunner} || 'Unknown',
  };
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

sub _build_input_fh {
  my $self = shift;

  return unless $self->input_file;

  open my $fh, '<', $self->input_file
    or croak "Cannot open input file '" . $self->input_file . "': $!";
  return $fh;
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
