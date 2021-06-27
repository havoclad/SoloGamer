package BufferedOutput;
use v5.10;

use Moose::Role;

has 'buffered_output' => (
  is      => 'rw',
  isa     => 'ArrayRef[Str]',
  default => sub { [ ] },
  lazy    => 1,
  clearer => 'flush',
);

sub buffer {
  my ($self, @lines) = @_;

  push $self->buffered_output->@*, @lines;
  return;
}

sub print_output {
  my $self = shift;

  say for $self->buffered_output->@*;
  $self->flush;
  return;
}

sub get_buffer_size {
  my $self = shift;

  return $self->buffered_output->$#*;
}

sub flush_to {
  my $self = shift;
  my $size = shift;

  $self->buffered_output->$#* = $size;
  return;

}

1;
