package BufferedOutput;
use v5.42;

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
    if ($line =~ /[^\x00-\xFF]/x) { # Checking for wide characters (Unicode > 255)
      # Temporarily set UTF-8 for this line only
      my $old_layers = join('', PerlIO::get_layers(STDOUT));
      binmode(STDOUT, ':encoding(UTF-8)') unless $old_layers =~ /encoding/;
      say $line;
      # Reset to original layers if we added encoding
      binmode(STDOUT, ':raw') if $old_layers !~ /encoding/;
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

sub buffer_roll_details {
  my ($self, $args) = @_;
  my $text = $self->formatter->format_roll_details($args);
  $self->buffer($text);
  return;
}

sub buffer_modifier_preview {
  my ($self, $modifiers) = @_;
  my $text = $self->formatter->format_modifier_preview($modifiers);
  $self->buffer($text) if $text;
  return;
}

sub buffer_modifier_applied {
  my ($self, $modifiers) = @_;
  my $text = $self->formatter->format_modifier_applied($modifiers);
  $self->buffer($text) if $text;
  return;
}

sub buffer_success {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_success($text));
  return;
}

sub buffer_info {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_info($text));
  return;
}

sub buffer_error {
  my ($self, $text) = @_;
  $self->buffer($self->formatter->format_error($text));
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
  my ($self, $text, $width, $color_scheme) = @_;
  $self->buffer($self->formatter->box_header($text, $width, $color_scheme));
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

sub buffer_zone_separator {
  my ($self, $width) = @_;
  $self->buffer($self->formatter->format_zone_separator($width));
  return;
}

1;
