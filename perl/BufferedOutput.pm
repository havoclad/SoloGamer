package BufferedOutput;
use v5.10;

use Moose::Role;
use SoloGamer::Formatter;

has 'buffered_output' => (
  is      => 'rw',
  isa     => 'ArrayRef[Str]',
  default => sub { [ ] },
  lazy    => 1,
  clearer => 'flush',
);

has 'formatter' => (
  is      => 'ro',
  isa     => 'SoloGamer::Formatter',
  default => sub { SoloGamer::Formatter->new() },
  lazy    => 1,
);

sub buffer {
  my ($self, @lines) = @_;

  push $self->buffered_output->@*, @lines;
  return;
}

sub print_output {
  my $self = shift;

  foreach my $line ($self->buffered_output->@*) {
    # Check if line contains wide characters (Unicode > 255)
    if ($line =~ /[^\x00-\xFF]/) {
      # Temporarily set UTF-8 for this line only
      my $old_layers = join('', PerlIO::get_layers(STDOUT));
      binmode(STDOUT, ':utf8') unless $old_layers =~ /utf8/;
      say $line;
      # Reset to original layers if we added utf8
      binmode(STDOUT, ':raw') if $old_layers !~ /utf8/;
    } else {
      say $line;
    }
  }
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

sub buffer_roll {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_roll($text));
  return;
}

sub buffer_success {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_success($text));
  return;
}

sub buffer_danger {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_danger($text));
  return;
}

sub buffer_location {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_location($text));
  return;
}

sub buffer_important {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_important($text));
  return;
}

sub buffer_header {
  my ($self, $text, $width) = @_;
  $self->buffer($self->formatter->box_header($text, $width));
  return;
}

sub buffer_progress {
  my ($self, $current, $total, $label, $width) = @_;
  my $text = $label ? "$label " : "";
  $text .= $self->formatter->progress_bar($current, $total, $width);
  $self->buffer($text);
  return;
}

sub buffer_table {
  my ($self, $title, $data) = @_;
  $self->buffer($self->formatter->format_table($title, $data));
  return;
}

1;
