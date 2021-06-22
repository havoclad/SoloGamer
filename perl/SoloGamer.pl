#!/usr/local/bin/perl

use strict;
use warnings;
use v5.10;

use Getopt::Long;

use Data::Dumper;

use lib '/perl';

use SoloGamer::Game;

my $info = 0;
my $debug = 0;
my $game_name = "";
my $save_file = "";
my $automated = 0;

GetOptions("info"        => \$info,
           "debug"       => \$debug,
           "game=s"      => \$game_name,
           "save_file:s" => \$save_file,
           "automated"   => \$automated,
   );

my $game = SoloGamer::Game->new(name      => $game_name, 
                                verbose   => $info,
                                save_file => $save_file,
                                automated => $automated,
                                );

my $data = $game->tables;

$game->run_game;

$debug and say Dumper $game;
