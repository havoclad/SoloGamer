package SoloGamer::FlowTable;
use v5.10;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Table';

sub __flow {
  my $self = shift;

  my $f = $self->data->{flow};

  my $a = [sort { $a <=> $b } keys %$f];

  foreach my $item (@$a) {
    say $item;
  }
  return $a;
}

has 'flow' => (
  is       => 'ro',
  isa      => 'ArrayRef',
  builder  => '__flow',
);

__PACKAGE__->meta->make_immutable;
1;
