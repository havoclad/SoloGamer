package SoloGamer::ColorScheme::TerminalClassic;
use v5.42;
use utf8;

use Moose;
with 'SoloGamer::ColorScheme';

sub name {
  return 'Terminal Classic'
}

sub description {
  return 'Classic terminal color scheme with magenta for welcome banners, cyan for missions, and white for outcomes'
}

sub get_color_for {
  my ($self, $text) = @_;
  
  my $context = $self->determine_context_type($text);
  
  my %colors = (
    outcome  => 'bright_white',
    welcome  => 'bright_magenta',
    mission  => 'bright_cyan',
    gameover => 'bright_red',
    default  => 'bold cyan',
  );
  
  return $colors{$context} // $colors{default};
}

__PACKAGE__->meta->make_immutable;
1;