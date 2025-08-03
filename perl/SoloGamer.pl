#!/usr/local/bin/perl

use strict;
use warnings;
use v5.10;

use Getopt::Long;

use lib '/perl';

use SoloGamer::Game;

my $info = 0;
my $debug = 0;
my $game_name = "";
my $save_file = "";
my $automated = 0;
my $use_color = 1;
my $help = 0;

sub validate_save_file {
  my ($opt_name, $opt_value) = @_;
  
  # Handle optional parameter case (no value provided)
  if (!defined $opt_value || $opt_value eq '') {
    $save_file = '';
    return;
  }
  
  # Security: validate filename contains no path separators or dangerous characters
  if ($opt_value =~ m{[/\\]} || $opt_value =~ m{\.\.} || $opt_value =~ m{^[.-]}) {
    die "Invalid save file name '$opt_value': must be a simple filename without paths, '..' sequences, or leading dots/dashes";
  }
  
  # Construct safe path within saves directory and store in global variable
  $save_file = '/app/saves/' . $opt_value;
  return;
}

GetOptions("info"        => \$info,
           "debug"       => \$debug,
           "game=s"      => \$game_name,
           "save_file:s" => \&validate_save_file,
           "automated"   => \$automated,
           "color!"      => \$use_color,
           "help|h"      => \$help,
   ) || die "Invalid options";

if ($help) {
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

my $game = SoloGamer::Game->new(name      => $game_name, 
                                verbose   => $info,
                                save_file => $save_file,
                                automated => $automated,
                                use_color => $use_color,
                                );

my $data = $game->tables;

$game->run_game;

$debug and say $game->dump;
