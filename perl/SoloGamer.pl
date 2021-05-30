#!/usr/local/bin/perl

use strict;
use v5.10;
use Data::Dumper;

use lib '/perl';

use SoloGamer::Game;

my $game_name = shift;

#my $p = SoloGamer::LoadTable->new(file=>'data/G-1.json');

#my $r = $p->roll();
#say "We're going to $r->{'Target'}";
#say "It's an $r->{'Type'}";
my $game = SoloGamer::Game->new(name=>$game_name);

my $data = $game->table;

$game->run_game;

say Dumper $data;
