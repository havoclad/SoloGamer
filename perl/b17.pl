#!/usr/local/bin/perl

use strict;

use Mojo::JSON qw(decode_json encode_json);

use lib '/perl';

use B17::LoadTable;
my $game = $ENV{'GAME'};
die "No game specified, use -e" unless $game;

my $p = B17::LoadTable::loadTable("/games/$game/data/G-1");

my $r = int(rand(6)) +1;

my $dest = $p->{$r}->{'Target'};
my $type = $p->{$r}->{'Type'};

print "Our target is the $type in $dest\n";

open (SAVE, ">",  "/save/pat") or die $!;
print SAVE encode_json($p);
close SAVE;

