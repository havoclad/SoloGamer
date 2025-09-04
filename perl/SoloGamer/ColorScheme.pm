package SoloGamer::ColorScheme;
use v5.42;
use utf8;

use Moose::Role;

requires qw(
  name
  description
  get_color_for
);

sub determine_context_type {
  my ($self, $text) = @_;
  
  # Determine the context type based on text patterns
  # Order matters - check more specific patterns first
  return 'outcome'   if $text =~ /OUTCOME/i;
  return 'welcome'   if $text =~ /Welcome to/i;
  return 'mission'   if $text =~ /MISSION/ismx;
  return 'gameover'  if $text =~ /PLAYTHROUGH OVER/i;
  return 'default';
}

1;