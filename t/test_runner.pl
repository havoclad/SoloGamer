#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use lib '/t/lib';
use lib '/perl';

use Test::Class::Moose::Load '/t/lib';
use Test::Class::Moose::CLI;

# Test::Class::Moose test runner
# This script can be used to run Test::Class::Moose tests directly
# without prove, useful for development and debugging

my $runner = Test::Class::Moose::CLI->new_with_options();
$runner->run();