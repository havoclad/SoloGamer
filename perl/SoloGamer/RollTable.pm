package SoloGamer::RollTable;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Table';

sub __roll {
  my $self = shift;

  my $d = $self->data->{rolls};
  my $r = (keys %$d)[rand keys %$d];

  printf "Rolled a $r on table %s %s\n", $self->name, $self->data->{Title};
  return $d->{$r};
}

has 'roll' => (
  is       => 'rw',
  isa      => 'HashRef',
  builder  => '__roll',
);

__PACKAGE__->meta->make_immutable;
1;
