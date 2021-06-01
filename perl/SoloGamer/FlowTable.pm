package SoloGamer::FlowTable;
use v5.20;

use Moose;
use namespace::autoclean;

use Data::Dumper;

extends 'SoloGamer::Table';

sub __order {
  my $self = shift;

  my $f = $self->data->{flow};

  my $a = [sort { $a <=> $b } keys %$f];

  foreach my $item (@$a) {
    say $item;
  }
  return $a;
}

has 'order' => (
  is       => 'ro',
  isa      => 'ArrayRef',
  builder  => '__order',
);

has 'current' => (
  is       => 'rw',
  isa      => 'Int',
  default  => '0',
);

sub get_next {
  my $self = shift;

  say "In get_next";
  if (exists $self->order->[$self->current]) {
    my $next = $self->order->[$self->current];
    say "Next is $next";
    return $self->data->{flow}->{$next};
  }
  return undef;
}

__PACKAGE__->meta->make_immutable;
1;
