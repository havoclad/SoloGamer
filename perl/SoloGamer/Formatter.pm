package SoloGamer::Formatter;
use v5.10;

use Moose;
use Term::ANSIColor;

has 'use_color' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 1,
  lazy    => 1,
);

sub format {
  my ($self, $text, $style) = @_;
  
  return $text unless $self->use_color && $style;
  
  return colored($text, $style);
}

sub format_roll {
  my ($self, $text) = @_;
  return $self->format($text, 'yellow');
}

sub format_success {
  my ($self, $text) = @_;
  return $self->format($text, 'green');
}

sub format_danger {
  my ($self, $text) = @_;
  return $self->format($text, 'red');
}

sub format_location {
  my ($self, $text) = @_;
  return $self->format($text, 'blue');
}

sub format_important {
  my ($self, $text) = @_;
  return $self->format($text, 'bold white');
}

sub format_header {
  my ($self, $text) = @_;
  return $self->format($text, 'bold cyan');
}

sub box_header {
  my ($self, $text, $width) = @_;
  
  $width //= length($text) + 4;
  my $padding = $width - length($text) - 2;
  my $left_pad = int($padding / 2);
  my $right_pad = $padding - $left_pad;
  
  my $top    = "╔" . ("═" x ($width - 2)) . "╗";
  my $middle = "║" . (" " x $left_pad) . $text . (" " x $right_pad) . "║";
  my $bottom = "╚" . ("═" x ($width - 2)) . "╝";
  
  return join("\n", 
    $self->format_header($top),
    $self->format_header($middle),
    $self->format_header($bottom)
  );
}

sub progress_bar {
  my ($self, $current, $total, $width) = @_;
  
  $width //= 10;
  my $filled = int(($current / $total) * $width);
  my $empty = $width - $filled;
  
  my $bar = "[" . ("█" x $filled) . ("░" x $empty) . "]";
  my $percent = sprintf("%3d%%", ($current / $total) * 100);
  
  return $self->format($bar, 'cyan') . " " . $percent;
}

sub format_table {
  my ($self, $title, $data) = @_;
  
  my @lines;
  my $max_key_len = 0;
  my $max_val_len = 0;
  
  foreach my $row (@$data) {
    my ($key, $val) = @$row;
    $max_key_len = length($key) if length($key) > $max_key_len;
    $max_val_len = length($val) if length($val) > $max_val_len;
  }
  
  my $width = $max_key_len + $max_val_len + 7;
  
  push @lines, "┌" . ("─" x ($max_key_len + 2)) . "┬" . ("─" x ($max_val_len + 2)) . "┐";
  push @lines, "│ " . sprintf("%-${max_key_len}s", $title) . " │ " . sprintf("%-${max_val_len}s", "Result") . " │";
  push @lines, "├" . ("─" x ($max_key_len + 2)) . "┼" . ("─" x ($max_val_len + 2)) . "┤";
  
  foreach my $row (@$data) {
    my ($key, $val) = @$row;
    push @lines, "│ " . sprintf("%-${max_key_len}s", $key) . " │ " . sprintf("%-${max_val_len}s", $val) . " │";
  }
  
  push @lines, "└" . ("─" x ($max_key_len + 2)) . "┴" . ("─" x ($max_val_len + 2)) . "┘";
  
  return join("\n", @lines);
}

sub weather_icon {
  my ($self, $weather) = @_;
  
  my %icons = (
    'Good'    => '☀',
    'Poor'    => '☁',
    'Bad'     => '⛈',
    'Storm'   => '⛈',
    'Unknown' => '?',
  );
  
  return $icons{$weather} // $icons{'Unknown'};
}

__PACKAGE__->meta->make_immutable;
1;