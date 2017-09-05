package B17::Game;

use strict;

use Moose;


has 'name' => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
  init_arg => 'name',
);

has 'source_data' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '_build_source_data',
);

has 'source' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '_build_source',
);

sub _build_source {
  my $self = shift;
  return '/games/' . $self->name . '/';
}

sub _build_source_data {
  my $self = shift;
  return $self->source . 'data/';
}


no Moose;
__PACKAGE__->meta->make_immutable;
