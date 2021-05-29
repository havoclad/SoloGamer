#!/usr/local/bin/perl

use strict;
use v5.10;
use lib '/perl';

use SoloGamer::LoadTable;

my $p = SoloGamer::LoadTable->new(file=>'data/G-1.json');

my $r = $p->roll();
say "We're going to $r->{'Target'}";
say "It's an $r->{'Type'}";

