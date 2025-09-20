package SoloGamer::ColorScheme::VintageWWII;
use v5.42;
use utf8;

use Moose;
with 'SoloGamer::ColorScheme';

sub name {
  return 'Vintage WWII'
}

sub description {
  return 'WWII-themed color scheme with brass/medal yellow for welcome banners, alert red for missions, and bright green for outcomes'
}

sub get_color_for {
  my ($self, $text) = @_;
  
  my $context = $self->determine_context_type($text);
  
  my %colors = (
    outcome  => 'bright_green',
    zone     => 'bright_green',
    welcome  => 'bright_yellow',
    mission  => 'bright_red',
    gameover => 'bright_white',
    default  => 'bold cyan',
  );
  
  return $colors{$context} // $colors{default};
}

__PACKAGE__->meta->make_immutable;
1;