package SoloGamer::Formatter;
use v5.42;
use utf8;

use Moose;
use Term::ANSIColor;
use SoloGamer::ColorScheme::Registry;

has 'use_color' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 1,
  lazy    => 1,
);

has 'color_registry' => (
  is      => 'ro',
  isa     => 'SoloGamer::ColorScheme::Registry',
  default => sub { SoloGamer::ColorScheme::Registry->new() },
  lazy    => 1,
);

has 'color_scheme' => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_color_scheme',
);

sub _build_color_scheme {
  my $self = shift;
  return $self->color_registry->get_scheme();
}

sub apply_format {
  my ($self, $text, $style) = @_;
  
  return $text unless $self->use_color && $style;
  
  return colored($text, $style);
}

sub format_roll {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'yellow');
}

sub format_success {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'green');
}

sub format_danger {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'red');
}

sub format_location {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'blue');
}

sub format_important {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'bold white');
}

sub format_header {
  my ($self, $text) = @_;
  return $self->apply_format($text, 'bold cyan');
}

sub box_header {
  my ($self, $text, $width, $color_scheme_id) = @_;
  
  $width //= length($text) + 4;
  my $padding = $width - length($text) - 2;
  my $left_pad = int($padding / 2);
  my $right_pad = $padding - $left_pad;
  
  my $top    = "╔" . ("═" x ($width - 2)) . "╗";
  my $middle = "║" . (" " x $left_pad) . $text . (" " x $right_pad) . "║";
  my $bottom = "╚" . ("═" x ($width - 2)) . "╝";
  
  # Get the appropriate color scheme
  my $scheme = $color_scheme_id 
    ? $self->color_registry->get_scheme($color_scheme_id)
    : $self->color_scheme;
  
  # Get color from the scheme
  my $color = $scheme->get_color_for($text);
  
  return join("\n", 
    $self->apply_format($top, $color),
    $self->apply_format($middle, $color),
    $self->apply_format($bottom, $color)
  );
}

sub progress_bar {
  my ($self, $current, $total, $width) = @_;
  
  $width //= 10;
  my $filled = int(($current / $total) * $width);
  my $empty = $width - $filled;
  
  my $bar = "[" . ("█" x $filled) . ("░" x $empty) . "]";
  my $percent = sprintf("%3d%%", ($current / $total) * 100);
  
  return $self->apply_format($bar, 'cyan') . " " . $percent;
}

sub format_modifier_preview {
  my ($self, $modifiers) = @_;
  
  return '' unless @$modifiers;
  
  my @lines;
  push @lines, $self->apply_format("Future rolls will be modified:", 'bright_black');
  
  foreach my $mod (@$modifiers) {
    my $table = $mod->{table};
    my $modifier = $mod->{modifier};
    my $why = $mod->{why};
    
    my $sign = $modifier >= 0 ? '+' : '';
    push @lines, $self->apply_format("  - $why ($table): $sign$modifier penalty", 'bright_black');
  }
  
  return join("\n", @lines);
}

sub format_modifier_applied {
  my ($self, $modifiers) = @_;
  
  return '' unless @$modifiers;
  
  my @lines;
  push @lines, $self->apply_format("Applied modifiers:", 'bright_black');
  
  foreach my $mod (@$modifiers) {
    my $modifier = $mod->{modifier};
    my $why = $mod->{why};
    
    my $sign = $modifier >= 0 ? '+' : '';
    push @lines, $self->apply_format("  - $why: $sign$modifier penalty", 'bright_black');
  }
  
  return join("\n", @lines);
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

sub format_zone_separator {
  my ($self, $width) = @_;
  
  $width //= 40;
  
  # Create a string of centered dots with spaces
  my $separator = join(' ', ('·') x ($width / 2));
  
  # Apply subtle gray color if colors are enabled
  return $self->apply_format($separator, 'bright_black');
}

sub format_roll_details {
  my ($self, $args) = @_;

  my $raw_result = $args->{raw_result};
  my $individual_rolls = $args->{individual_rolls};
  my $roll_type = $args->{roll_type};
  my $modifiers = $args->{modifiers};
  my $final_result = $args->{final_result};

  my $output = "";

  # Format the basic roll information
  if (@$individual_rolls > 1) {
    my $dice_str = "[" . join(",", @$individual_rolls) . "]";
    $output .= $self->apply_format("Rolling $roll_type: $dice_str = $raw_result", 'yellow');
  } else {
    $output .= $self->apply_format("Rolling $roll_type: $raw_result", 'yellow');
  }

  # Add modifier information if present
  if ($modifiers && $modifiers != 0) {
    my $sign = $modifiers >= 0 ? '+' : '';
    $output .= $self->apply_format(" $sign$modifiers modifiers", 'cyan');
    $output .= $self->apply_format(" = $final_result", 'yellow');
  }

  return $output;
}

__PACKAGE__->meta->make_immutable;
1;