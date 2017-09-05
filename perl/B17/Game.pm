package B17::Game;

use strict;

use Moose;


has 'name' => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
  init_arg => 'name',
);

no Moose;
__PACKAGE__->meta->make_immutable;
