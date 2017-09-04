#!/usr/local/bin/perl

use strict;

use File::Slurp;
use Mojo::JSON qw(decode_json encode_json);

my $game = $ENV{'GAME'};
die "No game specified, use -e" unless $game;

my $f = read_file("/games/$game/data/G-1");
my $p = decode_json($f);

my $r = int(rand(6)) +1;

my $dest = $p->{$r}->{'Target'};

print "We're going to $dest\n";

open (SAVE, ">",  "/save/pat") or die $!;
print SAVE encode_json($p);
close SAVE;

