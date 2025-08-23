#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use File::Find;

use lib 't/lib';
use lib 'perl';

# Test that all modules can be loaded without errors

my @modules_to_test = (
    # Core modules
    'SoloGamer::Base',
    'SoloGamer::Game',
    'SoloGamer::Table',
    'SoloGamer::TableFactory',
    'SoloGamer::SaveGame',
    'SoloGamer::TypeLibrary',
    'SoloGamer::Formatter',
    
    # Table types
    'SoloGamer::RollTable',
    'SoloGamer::FlowTable',
    'SoloGamer::OnlyIfRollTable',
    
    # Roles
    'Logger',
    'BufferedOutput',
);

plan tests => scalar @modules_to_test;

for my $module (@modules_to_test) {
    ok(eval "require $module; 1", "$module loads without errors") or diag $@;
}

done_testing();