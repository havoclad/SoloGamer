package SoloGamer::SaveGame;

use strict;
use v5.20;

use File::Copy;
use File::Slurp;

use Moose;
use Mojo::JSON qw ( encode_json decode_json );
use namespace::autoclean;

use Data::Dumper;

extends 'SoloGamer::Base';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'save'    => (
  is          => 'rw',
  isa         => 'HashRef',
  lazy        => 1,
  default     => sub { {} },
);

has 'mission' => (
  is       => 'rw',
  isa      => 'Int',
);

sub load_save {
  my $self = shift;

  my $save_to_load = $self->save_file;

  my $mission = 1;
  if (-e $save_to_load) {
    $self->devel("Trying to load $save_to_load");
    open(my $fh, "<", $save_to_load) or die("Can't open: ", $save_to_load);
    my $json = read_file($fh);
    close $fh;
    $self->save(decode_json($json)) or die $!;
    my $last_mission = $self->save->{mission}->$#* + 1;
    $self->devel("Last mission was: $last_mission");
    $mission = $last_mission + 1;
  } else {
    if ($save_to_load eq '') {
      $self->devel("No save file, use --save_file on command line to set");
    } else {
      $self->devel("No save file found at $save_to_load");
    }
    my $temp = { mission => [{}] };
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
    open(my $fh, ">", $tmp_file) or die "Can't open $tmp_file $!";
    print $fh encode_json($self->save) or die("Can't write file at: ", $tmp_file, " $!");
    close $fh;
    move($tmp_file, $self->save_file) or die("Can't move $tmp_file to ", $self->save_file);
  } else {
    $self->devel("No save file to write");
  }
}

sub add_save {
  my $self     = shift;
  my $property = shift;
  my $value    = shift;

  $self->save->{'mission'}->[$self->mission-1]->{$property} = $value;
}
__PACKAGE__->meta->make_immutable;