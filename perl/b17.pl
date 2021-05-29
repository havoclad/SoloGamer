#!/usr/local/bin/perl

use strict;
use v5.10;

use File::Slurp;
use Mojo::JSON qw(decode_json encode_json);

my $f = read_file('/data/G-1.json');
my $p = decode_json($f);

my $r = int(rand(6)) +1;

my $dest = $p->{$r}->{'Target'};

say "We're going to $dest";

open (SAVE, ">",  "/save/pat") or die $!;
print SAVE encode_json($p);
close SAVE;

