#!/usr/local/bin/perl

use strict;
use v5.10;
use Data::Dumper;

use lib '/perl';

use SoloGamer::Game;

my $game_name = shift;
my $verbose = shift || 0;

my $game = SoloGamer::Game->new(name    =>$game_name, 
	                        verbose => $verbose);

my $data = $game->table;

$game->run_game;

$verbose == 2 and say Dumper $data;
