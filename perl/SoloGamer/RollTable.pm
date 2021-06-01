package SoloGamer::RollTable;
use v5.20;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Table';

sub __roll {
  my $self = shift;

  my $d = $self->rolls;
  my $r = (keys %$d)[rand keys %$d];

  $self->devel("Rolled a $r on table " . $self->name . " " .  $self->title);
  return $d->{$r};
}

sub __roll_type {
  my $self = shift;

  my $roll_type = $self->data->{'rolltype'};
  delete $self->data->{'rolltype'};
  return $roll_type;
}

has 'roll_type' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '__roll_type',
);

has 'roll' => (
  is       => 'rw',
  isa      => 'HashRef',
  lazy     => 1,
  builder  => '__roll',
);

sub __rolls {
  my $self = shift;

  my $hr = {};
  foreach my $key (keys $self->data->{rolls}->%*) {
    $hr->{$key} = $self->data->{rolls}->{$key};
  }
  delete $self->data->{rolls};
  return $hr;
}

has 'rolls' => (
  is       => 'ro',
  isa      => 'HashRef',
  builder  => '__rolls',
);
__PACKAGE__->meta->make_immutable;
1;
