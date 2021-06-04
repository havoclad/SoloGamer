#!/usr/local/bin/perl

use strict;
use v5.10;

use Getopt::Long;

use Data::Dumper;

use lib '/perl';

use SoloGamer::Game;

my $info = 0;
my $debug = 0;
my $game_name = "";
my $save_file = "";

GetOptions("info:i"      => \$info,
	   "debug:i"     => \$debug,
	   "game=s"      => \$game_name,
	   "save_file:s" => \$save_file,
   );

my $game = SoloGamer::Game->new(name      => $game_name, 
	                        verbose   => $info,
				save_file => $save_file,
			        );

my $data = $game->table;

$game->run_game;

$debug and say Dumper $game;
