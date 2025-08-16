#!/usr/local/bin/perl

use strict;
use warnings;
use v5.10;

use Getopt::Long;

use lib '/perl';

use SoloGamer::Game;

# Note: UTF-8 handling is managed at the data level
# Box drawing and weather icons are stored as UTF-8 in the source files

my %options = (
  info      => 0,
  debug     => 0,
  game      => "",
  save_file => "",
  automated => 0,
  color     => 1,
  help      => 0,
);

sub validate_save_file {
  my ($opt_name, $opt_value) = @_;
  
  # Handle optional parameter case (no value provided)
  if (!defined $opt_value || $opt_value eq '') {
    $options{save_file} = '';
    return;
  }
  
  # Security: validate filename contains only word characters (letters, numbers, underscore)
  if ($opt_value !~ /^\w+$/) {
    die "Invalid save file name '$opt_value': must contain only letters, numbers, and underscores";
  }
  
  # Append .json extension if not present
  my $filename = $opt_value;
  $filename .= '.json' unless $filename =~ /\.json$/;
  
  # Construct safe path within saves directory and store in global variable
  $options{save_file} = '/app/saves/' . $filename;
  return;
}

GetOptions("info"        => \$options{info},
           "debug"       => \$options{debug},
           "game=s"      => \$options{game},
           "save_file:s" => \&validate_save_file,
           "automated"   => \$options{automated},
           "color!"      => \$options{color},
           "help|h"      => \$options{help},
   ) || die "Invalid options";

if ($options{help}) {
  print <<'EOF';
Usage: SoloGamer.pl [options]

Options:
  --game=NAME        Set game name (default: QotS)
  --save_file[=NAME] Save/load game to specified file
  --automated        Run in automated mode (no user input)
  --info             Enable verbose logging
  --debug            Enable debug output at end of game
  --color, --no-color Enable/disable colored output (default: enabled)
  --help, -h         Show this help message

Examples:
  SoloGamer.pl                      # Run QotS interactively
  SoloGamer.pl --automated          # Run QotS automated
  SoloGamer.pl --save_file=mysave   # Load specific save file
  SoloGamer.pl --info --debug       # Run with verbose output and debug
EOF
  exit 0;
}

# Default to QotS if no game specified
$options{game} ||= 'QotS';

# Use the factory method to instantiate the appropriate game class
my $game = SoloGamer::Game->new_game(
  name      => $options{game},
  verbose   => $options{info},
  save_file => $options{save_file},
  automated => $options{automated},
  use_color => $options{color},
);

my $data = $game->tables;

$game->run_game;

$options{debug} and say $game->dump;
