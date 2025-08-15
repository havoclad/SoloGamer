package SoloGamer::FlowTable;
use v5.42;

use Moose;
use namespace::autoclean;

use SoloGamer::TypeLibrary qw / NonNegativeInt /;

extends 'SoloGamer::Table';

sub _build_flow {
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
  builder  => '_build_flow',
);

has 'current' => (
  is       => 'rw',
  isa      => NonNegativeInt,
  default  => '0',
);

sub get_next {
  my $self = shift;

  my $current = $self->current;
  $self->devel("In get_next with current: ", $current, " and last array index of: ", $self->flow->$#*);

  if ($current > $self->flow->$#*) {
    $self->devel("Done with flow");
    return;
  }
  
  my $result = $self->flow->[$current];
  $self->current($current + 1);
  return $result;
}

__PACKAGE__->meta->make_immutable;
1;
