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

GetOptions("info"        => \$info,
           "debug"       => \$debug,
           "game=s"      => \$game_name,
           "save_file:s" => \$save_file,
           "automated"   => \$automated,
           "color!"      => \$use_color,
   );

my $game = SoloGamer::Game->new(name      => $game_name, 
                                verbose   => $info,
                                save_file => $save_file,
                                automated => $automated,
                                use_color => $use_color,
                                );

my $data = $game->tables;

$game->run_game;

$debug and say $game->dump;
