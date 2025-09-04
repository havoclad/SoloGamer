package SoloGamer::ColorScheme::MilitaryGreen;
use v5.42;
use utf8;

use Moose;
with 'SoloGamer::ColorScheme';

sub name {
  'Military Green & Gold'
}

sub description {
  'Military-themed color scheme with green for welcome banners, gold for missions, and bright yellow for outcomes'
}

sub get_color_for {
  my ($self, $text) = @_;
  
  my $context = $self->determine_context_type($text);
  
  my %colors = (
    outcome  => 'bright_yellow',
    welcome  => 'bright_green',
    mission  => 'yellow',
    gameover => 'bright_magenta',
    default  => 'bold cyan',
  );
  
  return $colors{$context} // $colors{default};
}

__PACKAGE__->meta->make_immutable;
1;