#!/usr/local/bin/perl

use strict;

use Mojo::JSON qw(decode_json encode_json);

use lib '/perl';

use B17::Game;
use B17::LoadTable;

my $game = new B17::Game(
  name => $ENV{'GAME'},
);

my $s = $game->source_data;
my $p = new B17::LoadTable( file => $s . 'G-1');

my $r = $p->roll;

my $dest = $r->{'Target'};
my $type = $r->{'Type'};

print "Our target is the $type in $dest\n";

open (SAVE, ">",  "/save/pat") or die $!;
print SAVE encode_json($p);
close SAVE;

