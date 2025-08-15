package Logger;
use v5.42;
use feature 'signatures';
no warnings 'experimental::signatures';

use Moose::Role;

sub devel ($self, @lines) {

  if ($self->verbose) {
    say @lines;
  }
  return;
}

has 'verbose' => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => 0,
  init_arg => 'verbose',
);

1;
