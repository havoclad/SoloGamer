package Logger;
use v5.10;

use Moose::Role;

sub devel {
  my ($self, @lines)  = @_;

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
