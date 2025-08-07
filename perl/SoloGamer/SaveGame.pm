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

sub load_save {
  my $self = shift;

  my $save_to_load = $self->save_file;

  my $mission = 1;
  if ($save_to_load && -e $save_to_load) {
    $self->devel("Trying to load $save_to_load");
    my $json = read_file($save_to_load);
    my $decoded = decode_json($json);
    $self->save($decoded) or croak $!;
    
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
    
    my $temp = { 
      mission => [{}],
      plane_name => $plane_name 
    };
    $self->save($temp);
  }
  $self->mission($mission);
  return $mission;

}

sub save_game {
  my $self = shift;

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
__PACKAGE__->meta->make_immutable;
1;
