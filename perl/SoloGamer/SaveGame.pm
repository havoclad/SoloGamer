package SoloGamer::SaveGame;

use strict;
use v5.20;

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
      $self->devel("No mission array found in save data");
    }
  } else {
    if ($save_to_load eq '') {
      $self->devel("No save file, use --save_file on command line to set");
    } else {
      $self->devel("No save file found at $save_to_load");
    }
    
    # Create new save with plane name selection
    my $plane_namer = SoloGamer::QotS::PlaneNamer->new(automated => $self->automated);
    my $plane_name = $plane_namer->prompt_for_plane_name();
    
    # Create new crew
    my $crew = SoloGamer::QotS::Crew->new(automated => $self->automated);
    
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
    $self->devel("Writing save file to ", $self->save_file);
    my $tmp_file = $self->save_file . '.tmp';
    open(my $fh, ">", $tmp_file) or croak "Can't open $tmp_file $!";
    print $fh encode_json($self->save) or croak("Can't write file at: ", $tmp_file, " $!");
    close $fh;
    move($tmp_file, $self->save_file) or croak("Can't move $tmp_file to ", $self->save_file);
  } else {
    $self->devel("No save file to write");
  }
  return;
}

sub add_save {
  my $self     = shift;
  my $property = shift;
  my $value    = shift;

  $self->save->{'mission'}->[$self->mission-1]->{$property} = $value;
  return;
}

sub get_from_current_mission {
  my $self = shift;
  my $property = shift;

  $self->devel("Looking for $property in mission: ", $self->mission);
  return $self->save->{'mission'}->[$self->mission-1]->{$property};
}

sub get_plane_name {
  my $self = shift;
  
  return $self->save->{'plane_name'} || 'Unnamed B-17';
}

sub _build_crew {
  my $self = shift;
  
  if (exists $self->save->{crew}) {
    return SoloGamer::QotS::Crew->from_hash($self->save->{crew}, $self->automated);
  }
  
  return undef;
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
}

__PACKAGE__->meta->make_immutable;
1;
