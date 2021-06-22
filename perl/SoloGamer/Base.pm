package SoloGamer::Base;
use v5.10;

use Moose;
use namespace::autoclean;

sub devel {
  my ($self, @lines)  = @_;

  if ($self->verbose) {
    say @lines;
  }
  return;
}

has 'verbose' => (
  is      => 'ro',
  isa     => 'Int',
  lazy    => 1,
  default => 0,
  init_arg => 'verbose',
);

__PACKAGE__->meta->make_immutable;
1;
