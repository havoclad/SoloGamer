#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use File::Temp;
use File::Path qw(make_path);

use lib 't/lib';
use lib 'perl';

plan tests => 12;

# Test input_file functionality for PlaneNamer and CrewNamer
# These tests verify that input can be read from files for scripted interaction

my $temp_dir = File::Temp->newdir();
my $games_dir = "$temp_dir/games/QotS";
make_path($games_dir);

# Create test name files
my $generated_names = join("\n", (
    'Sky Bomber',
    'Thunder Bird',
    'Hell\'s Angels',
    'Memphis Belle',
    'Flying Fortress'
));

my $verified_names = join("\n", (
    'Memphis Belle',
    'Hell\'s Angels',
    'Yankee Doodle',
    'Ball of Fire',
    'Shoo Shoo Shoo Baby'
));

my $first_names = join("\n", (
    'John',
    'Robert',
    'William',
    'James',
    'Charles'
));

my $last_names = join("\n", (
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones'
));

open my $gen_fh, '>', "$games_dir/generated_b17_bomber_names.txt";
print $gen_fh $generated_names;
close $gen_fh;

open my $ver_fh, '>', "$games_dir/verified_b17_bomber_names.txt";
print $ver_fh $verified_names;
close $ver_fh;

open my $first_fh, '>', "$games_dir/1940s_male_first_names.txt";
print $first_fh $first_names;
close $first_fh;

open my $last_fh, '>', "$games_dir/1940s_male_last_names.txt";
print $last_fh $last_names;
close $last_fh;

require SoloGamer::QotS::PlaneNamer;
require SoloGamer::QotS::CrewNamer;

# Test 1: PlaneNamer with input_file - accept default
subtest 'PlaneNamer with input_file - accept default' => sub {
    plan tests => 2;
    
    my $input_file = File::Temp->new();
    print $input_file "accept\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    ok(defined $name, 'name is defined when reading from input file');
    ok(length($name) > 0, 'name has content when reading from input file');
};

# Test 2: PlaneNamer with input_file - reroll then accept
subtest 'PlaneNamer with input_file - reroll then accept' => sub {
    plan tests => 2;
    
    my $input_file = File::Temp->new();
    print $input_file "reroll\naccept\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    ok(defined $name, 'name is defined after reroll from input file');
    ok(length($name) > 0, 'name has content after reroll from input file');
};

# Test 3: PlaneNamer with input_file - custom name
subtest 'PlaneNamer with input_file - custom name' => sub {
    plan tests => 2;
    
    my $input_file = File::Temp->new();
    print $input_file "custom\nTest Bomber\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    ok(defined $name, 'custom name is defined from input file');
    is($name, 'Test Bomber', 'custom name matches input from file');
};

# Test 4: PlaneNamer with input_file - short form commands
subtest 'PlaneNamer with input_file - short form commands' => sub {
    plan tests => 2;
    
    my $input_file = File::Temp->new();
    print $input_file "r\nv\nc\nMy Plane\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    ok(defined $name, 'name is defined with short form commands');
    is($name, 'My Plane', 'custom name matches when using short form commands');
};

# Test 5: CrewNamer with input_file - accept all
subtest 'CrewNamer with input_file - accept all' => sub {
    plan tests => 3;
    
    my $input_file = File::Temp->new();
    print $input_file "accept\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::CrewNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        first_names_file => "$games_dir/1940s_male_first_names.txt",
        last_names_file => "$games_dir/1940s_male_last_names.txt"
    );
    
    my $positions = [
        'pilot', 'copilot', 'bombardier', 'navigator', 'engineer',
        'radio_operator', 'ball_gunner', 'port_waist_gunner', 
        'starboard_waist_gunner', 'tail_gunner'
    ];
    
    my $crew_names = $namer->prompt_for_crew_names($positions);
    
    ok(defined $crew_names, 'crew names are defined when reading from input file');
    is(ref($crew_names), 'ARRAY', 'crew names return an array reference');
    is(scalar(@$crew_names), 10, 'got exactly 10 crew members');
};

# Test 6: CrewNamer with input_file - reroll then accept
subtest 'CrewNamer with input_file - reroll then accept' => sub {
    plan tests => 3;
    
    my $input_file = File::Temp->new();
    print $input_file "reroll\naccept\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::CrewNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        first_names_file => "$games_dir/1940s_male_first_names.txt",
        last_names_file => "$games_dir/1940s_male_last_names.txt"
    );
    
    my $positions = [
        'pilot', 'copilot', 'bombardier', 'navigator', 'engineer',
        'radio_operator', 'ball_gunner', 'port_waist_gunner', 
        'starboard_waist_gunner', 'tail_gunner'
    ];
    
    my $crew_names = $namer->prompt_for_crew_names($positions);
    
    ok(defined $crew_names, 'crew names are defined after reroll from input file');
    is(ref($crew_names), 'ARRAY', 'crew names return an array reference after reroll');
    is(scalar(@$crew_names), 10, 'got exactly 10 crew members after reroll');
};

# Test 7: CrewNamer with input_file - individual naming with defaults
subtest 'CrewNamer with input_file - individual naming with defaults' => sub {
    plan tests => 4;
    
    my $input_file = File::Temp->new();
    # Accept suggested names for all 10 positions
    print $input_file "individual\n" . ("\n" x 10);
    close $input_file;
    
    my $namer = SoloGamer::QotS::CrewNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        first_names_file => "$games_dir/1940s_male_first_names.txt",
        last_names_file => "$games_dir/1940s_male_last_names.txt"
    );
    
    my $positions = [
        'pilot', 'copilot', 'bombardier', 'navigator', 'engineer',
        'radio_operator', 'ball_gunner', 'port_waist_gunner', 
        'starboard_waist_gunner', 'tail_gunner'
    ];
    
    my $crew_names = $namer->prompt_for_crew_names($positions);
    
    ok(defined $crew_names, 'crew names are defined with individual naming');
    is(ref($crew_names), 'ARRAY', 'crew names return an array reference with individual naming');
    is(scalar(@$crew_names), 10, 'got exactly 10 crew members with individual naming');
    
    my $first_member = $crew_names->[0];
    ok(defined $first_member->{name} && length($first_member->{name}) > 0, 
       'first crew member has a name with individual naming');
};

# Test 8: CrewNamer with input_file - custom names
subtest 'CrewNamer with input_file - custom names' => sub {
    plan tests => 4;
    
    my $input_file = File::Temp->new();
    # Custom naming with specific names
    print $input_file "custom\n";
    print $input_file "John Doe\nJane Smith\nBob Johnson\nAlice Brown\nCharlie Wilson\n";
    print $input_file "David Miller\nEve Davis\nFrank Garcia\nGrace Rodriguez\nHank Martinez\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::CrewNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        first_names_file => "$games_dir/1940s_male_first_names.txt",
        last_names_file => "$games_dir/1940s_male_last_names.txt"
    );
    
    my $positions = [
        'pilot', 'copilot', 'bombardier', 'navigator', 'engineer',
        'radio_operator', 'ball_gunner', 'port_waist_gunner', 
        'starboard_waist_gunner', 'tail_gunner'
    ];
    
    my $crew_names = $namer->prompt_for_crew_names($positions);
    
    ok(defined $crew_names, 'crew names are defined with custom naming');
    is(ref($crew_names), 'ARRAY', 'crew names return an array reference with custom naming');
    is(scalar(@$crew_names), 10, 'got exactly 10 crew members with custom naming');
    is($crew_names->[0]->{name}, 'John Doe', 'first custom name matches input');
};

# Test 9: CrewNamer with input_file - short form commands
subtest 'CrewNamer with input_file - short form commands' => sub {
    plan tests => 3;
    
    my $input_file = File::Temp->new();
    print $input_file "r\naccept\n";
    close $input_file;
    
    my $namer = SoloGamer::QotS::CrewNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        first_names_file => "$games_dir/1940s_male_first_names.txt",
        last_names_file => "$games_dir/1940s_male_last_names.txt"
    );
    
    my $positions = [
        'pilot', 'copilot', 'bombardier', 'navigator', 'engineer',
        'radio_operator', 'ball_gunner', 'port_waist_gunner', 
        'starboard_waist_gunner', 'tail_gunner'
    ];
    
    my $crew_names = $namer->prompt_for_crew_names($positions);
    
    ok(defined $crew_names, 'crew names work with short form commands');
    is(ref($crew_names), 'ARRAY', 'crew names return array with short form commands');
    is(scalar(@$crew_names), 10, 'got exactly 10 crew members with short form commands');
};

# Test 10: Input file with EOF - should fall back to defaults
subtest 'Input file EOF handling' => sub {
    plan tests => 2;
    
    my $input_file = File::Temp->new();
    # Empty file - will hit EOF immediately
    close $input_file;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => $input_file->filename,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    ok(defined $name, 'name is defined when input file reaches EOF');
    ok(length($name) > 0, 'name has content when input file reaches EOF');
};

# Test 11: Non-existent input file handling
subtest 'Non-existent input file handling' => sub {
    plan tests => 1;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => '/nonexistent/file.txt',
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # This should die with a useful error message
    like(
        dies { $namer->prompt_for_plane_name() },
        qr/Cannot open input file.*nonexistent.*file\.txt/,
        'Dies with helpful error for non-existent input file'
    );
};

# Test 12: Empty input_file parameter (should work normally)
subtest 'Empty input_file parameter' => sub {
    plan tests => 2;
    
    # Simulate pressing Enter (accept suggested name)
    my $input = "\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => '',  # Empty string should fall back to normal behavior
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'name is defined with empty input_file');
    ok(length($name) > 0, 'name has content with empty input_file');
};

done_testing();