package SoloGamer::ColorScheme::ClassicAviation;
use v5.42;
use utf8;

use Moose;
with 'SoloGamer::ColorScheme';

sub name {
  'Classic Aviation'
}

sub description {
  'Aviation-themed color scheme with sky blue for welcome banners, clean white for missions, and bright cyan for outcomes'
}

sub get_color_for {
  my ($self, $text) = @_;
  
  my $context = $self->determine_context_type($text);
  
  my %colors = (
    outcome  => 'bright_cyan',
    welcome  => 'bright_blue',
    mission  => 'white',
    gameover => 'bright_yellow',
    default  => 'bold cyan',
  );
  
  return $colors{$context} // $colors{default};
}

__PACKAGE__->meta->make_immutable;
1;