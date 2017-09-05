#!/usr/local/bin/perl

use strict;

use Mojo::JSON qw(decode_json encode_json);

use lib '/perl';

use B17::Game;
use B17::LoadTable;

my $game = new B17::Game(
  name => $ENV{'GAME'},
);

my $g = $game->name;
my $p = B17::LoadTable::loadTable("/games/$g/data/G-1");

my $r = int(rand(6)) +1;

my $dest = $p->{$r}->{'Target'};
my $type = $p->{$r}->{'Type'};

print "Our target is the $type in $dest\n";

open (SAVE, ">",  "/save/pat") or die $!;
print SAVE encode_json($p);
close SAVE;

