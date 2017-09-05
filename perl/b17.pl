#!/usr/local/bin/perl

use strict;
use warnings;

use lib '/perl';

use B17::Game;

my $game = new B17::Game(
  name => $ENV{'GAME'},
);

my $r = $game->table->{'G-1'}->roll;

printf "Our target is the %s in %s.\n", $r->{Type}, $r->{Target};

