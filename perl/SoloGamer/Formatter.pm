package SoloGamer::Formatter;
use v5.42;
use utf8;

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
  my ($self, $text, $width, $color_scheme) = @_;
  
  $width //= length($text) + 4;
  my $padding = $width - length($text) - 2;
  my $left_pad = int($padding / 2);
  my $right_pad = $padding - $left_pad;
  
  my $top    = "╔" . ("═" x ($width - 2)) . "╗";
  my $middle = "║" . (" " x $left_pad) . $text . (" " x $right_pad) . "║";
  my $bottom = "╚" . ("═" x ($width - 2)) . "╝";
  
  # Determine color based on text content or explicit scheme
  my $color = $self->_get_banner_color($text, $color_scheme);
  
  return join("\n", 
    $self->format($top, $color),
    $self->format($middle, $color),
    $self->format($bottom, $color)
  );
}

sub _get_banner_color {
  my ($self, $text, $scheme) = @_;
  
  # Option 1: Military Green & Gold Theme
  # - Welcome banners: bright green (military green)
  # - Mission headers: yellow/gold (command briefing)
  # - Outcome headers: bright yellow/gold
  
  # Option 2: Classic Aviation Theme  
  # - Welcome banners: bright blue (sky blue)
  # - Mission headers: white (clean cockpit)
  # - Outcome headers: bright cyan
  
  # Option 3: Vintage WWII Theme
  # - Welcome banners: bright_yellow (brass/medal)
  # - Mission headers: bright_red (alert/mission)
  # - Outcome headers: bright_green
  
  # Option 4: Terminal Classic
  # - Welcome banners: bright_magenta
  # - Mission headers: bright_cyan
  # - Outcome headers: bright_white
  
  # Default to scheme 4 (Terminal Classic)
  $scheme //= $ENV{BANNER_COLOR_SCHEME} // 4;
  
  # Check for OUTCOME first (more specific pattern)
  if ($text =~ /OUTCOME/i) {
    return 'bright_yellow' if $scheme == 1;
    return 'bright_cyan' if $scheme == 2;
    return 'bright_green' if $scheme == 3;
    return 'bright_white' if $scheme == 4;
  }
  elsif ($text =~ /Welcome to/i) {
    return 'bright_green' if $scheme == 1;
    return 'bright_blue' if $scheme == 2;
    return 'bright_yellow' if $scheme == 3;
    return 'bright_magenta' if $scheme == 4;
  }
  elsif ($text =~ /MISSION \d+/i || $text =~ /MISSION/i) {
    return 'yellow' if $scheme == 1;
    return 'white' if $scheme == 2;
    return 'bright_red' if $scheme == 3;
    return 'bright_cyan' if $scheme == 4;
  }
  elsif ($text =~ /PLAYTHROUGH OVER/i) {
    return 'bright_magenta' if $scheme == 1;
    return 'bright_yellow' if $scheme == 2;
    return 'bright_white' if $scheme == 3;
    return 'bright_red' if $scheme == 4;
  }
  
  # Default fallback
  return 'bold cyan';
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

sub format_modifier_preview {
  my ($self, $modifiers) = @_;
  
  return '' unless @$modifiers;
  
  my @lines;
  push @lines, $self->format("Future rolls will be modified:", 'bright_black');
  
  foreach my $mod (@$modifiers) {
    my $table = $mod->{table};
    my $modifier = $mod->{modifier};
    my $why = $mod->{why};
    
    my $sign = $modifier >= 0 ? '+' : '';
    push @lines, $self->format("  - $why ($table): $sign$modifier penalty", 'bright_black');
  }
  
  return join("\n", @lines);
}

sub format_modifier_applied {
  my ($self, $modifiers) = @_;
  
  return '' unless @$modifiers;
  
  my @lines;
  push @lines, $self->format("Applied modifiers:", 'bright_black');
  
  foreach my $mod (@$modifiers) {
    my $modifier = $mod->{modifier};
    my $why = $mod->{why};
    
    my $sign = $modifier >= 0 ? '+' : '';
    push @lines, $self->format("  - $why: $sign$modifier penalty", 'bright_black');
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
  return $self->format($separator, 'bright_black');
}

sub format_roll_details {
  my ($self, $raw_result, $individual_rolls, $roll_type, $modifiers, $final_result) = @_;
  
  my $output = "";
  
  # Format the basic roll information
  if (@$individual_rolls > 1) {
    my $dice_str = "[" . join(",", @$individual_rolls) . "]";
    $output .= $self->format("Rolling $roll_type: $dice_str = $raw_result", 'yellow');
  } else {
    $output .= $self->format("Rolling $roll_type: $raw_result", 'yellow');
  }
  
  # Add modifier information if present
  if ($modifiers && $modifiers != 0) {
    my $sign = $modifiers >= 0 ? '+' : '';
    $output .= $self->format(" $sign$modifiers modifiers", 'cyan');
    $output .= $self->format(" = $final_result", 'yellow');
  }
  
  return $output;
}

__PACKAGE__->meta->make_immutable;
1;