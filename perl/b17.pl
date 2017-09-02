#!/usr/local/bin/perl

use strict;

use JSON::Parse qw/json_file_to_perl parse_json/;

my $p = json_file_to_perl('/data/G-1');

my $r = int(rand(6)) +1;

my $dest = $p->{$r}->{'Target'};

print "We're going to $dest\n";

