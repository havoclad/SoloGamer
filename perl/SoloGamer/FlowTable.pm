package SoloGamer::FlowTable;
use v5.20;

use Moose;
use namespace::autoclean;

use Data::Dumper;

extends 'SoloGamer::Table';

sub __flow {
  my $self = shift;

  my $temp = [];
  my $json_flow = $self->data->{'flow'};
  foreach my $item ($json_flow->@*) {
    push @$temp, $item;
  }
  delete $self->data->{'flow'};
  return $temp;
}

has 'flow' => (
  is       => 'ro',
  isa      => 'ArrayRef',
  builder  => '__flow',
);

has 'current' => (
  is       => 'rw',
  isa      => 'Int',
  default  => '-1',
);

sub get_next {
  my $self = shift;

  $self->devel("In get_next");
  my $current = $self->current($self->current + 1);
  $self->devel("Current is: ", $current);
  $self->devel("Last array index is ", $self->flow->$#*);

  if ($current > $self->flow->$#*) {
    $self->devel("Done with flow");
    return undef;
  }
  return $self->flow->[$current];
}

__PACKAGE__->meta->make_immutable;
1;
