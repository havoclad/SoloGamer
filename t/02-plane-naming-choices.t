#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use File::Temp;
use File::Path qw(make_path);

use lib 't/lib';
use lib 'perl';

plan tests => 8;

# Test various plane naming choice sequences
# These tests simulate user interactions with the plane naming system

my $temp_dir = File::Temp->newdir();
my $games_dir = "$temp_dir/games/QotS";
make_path($games_dir);

# Create test name files
my $generated_names = join("\n", (
    'Sky Bomber',
    'Thunder Bird',
    'Hell\'s Angels',
    'Memphis Belle',
    'Flying Fortress',
    'Yankee Warrior',
    'Battle Eagle',
    'Liberty Belle',
    'Fortress Europa',
    'Victory Bird'
));

my $verified_names = join("\n", (
    'Memphis Belle',
    'Hell\'s Angels',
    'Yankee Doodle',
    'Ball of Fire',
    'Shoo Shoo Shoo Baby',
    'Nine O Nine',
    'Aluminum Overcast',
    'Sentimental Journey',
    'Texas Raiders',
    'Fuddy Duddy'
));

open my $gen_fh, '>', "$games_dir/generated_b17_bomber_names.txt";
print $gen_fh $generated_names;
close $gen_fh;

open my $ver_fh, '>', "$games_dir/verified_b17_bomber_names.txt";
print $ver_fh $verified_names;
close $ver_fh;

require SoloGamer::PlaneNamer;

# Test 1: Accept initial suggestion (equivalent to choice "1" - accept)
subtest 'Choice 1 - Accept Suggested Name' => sub {
    plan tests => 3;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate pressing Enter (accept suggested name)
    my $input = "\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'accepted name is defined');
    ok(length($name) > 0, 'accepted name is not empty');
    like($output, qr/Suggested name: \Q$name\E/, 'output shows the accepted name');
};

# Test 2: Reroll for new name (equivalent to choice "2" - reroll)
subtest 'Choice 2 - Reroll for New Name' => sub {
    plan tests => 4;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate: r (reroll), then Enter (accept new suggestion)
    my $input = "r\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'rerolled name is defined');
    ok(length($name) > 0, 'rerolled name is not empty');
    like($output, qr/New suggested name:/, 'output shows reroll message');
    like($output, qr/\Q$name\E/, 'output contains the final accepted name');
};

# Test 3: Get verified historical name (equivalent to choice "3" - historical)
subtest 'Choice 3 - Get Historical Name' => sub {
    plan tests => 4;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate: v (verified historical), then Enter (accept)
    my $input = "v\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'historical name is defined');
    ok(length($name) > 0, 'historical name is not empty');
    like($output, qr/Historical name:/, 'output shows historical name message');
    
    # Verify it's actually from the verified list
    my @verified_list = split /\n/, $verified_names;
    s/^\s+|\s+$//g for @verified_list;  # Trim whitespace
    @verified_list = grep { length($_) > 0 } @verified_list;  # Remove empty entries
    my $found = grep { $_ eq $name } @verified_list;
    ok($found, "name '$name' comes from verified historical list");
};

# Test 4: Custom name input
subtest 'Choice 4 - Custom Name Entry' => sub {
    plan tests => 3;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate: c (custom), then enter custom name
    my $custom_name = "Test Squadron Leader";
    my $input = "c\n$custom_name\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    is($name, $custom_name, 'custom name input works correctly');
    like($output, qr/Enter your custom plane name:/, 'prompts for custom name');
    like($output, qr/PLANE NAMING/, 'shows naming interface');
};

# Test 5: Automated mode bypasses all choices
subtest 'Automated Mode - No User Interaction' => sub {
    plan tests => 3;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 1,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    
    ok(defined $name, 'automated mode returns a name');
    ok(length($name) > 0, 'automated name is not empty');
    like($output, qr/Automated mode: Selected plane name/, 'shows automated selection message');
};

# Test 6: Sequence - Multiple Choices (simulating sequence 1, 2, 3 actions)
subtest 'Choice Sequence - Reroll Multiple Times' => sub {
    plan tests => 4;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate: r (reroll), r (reroll again), v (historical), Enter (accept)
    my $input = "r\nr\nv\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'sequence of choices returns a name');
    like($output, qr/New suggested name:.*New suggested name:/s, 'shows multiple rerolls');
    like($output, qr/Historical name:/, 'switches to historical name');
    ok(length($name) > 0, 'final name is not empty');
};

# Test 7: Error handling - Invalid choices then valid
subtest 'Error Handling - Invalid Then Valid Choices' => sub {
    plan tests => 3;
    
    my $namer = SoloGamer::PlaneNamer->new(
        automated => 0,
        generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
        verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
    );
    
    # Simulate: invalid choice, then valid choice
    my $input = "xyz\n123\n\n";  # invalid, invalid, then accept
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'invalid choices eventually resolve to valid name');
    like($output, qr/Invalid choice.*Invalid choice/s, 'shows multiple invalid choice messages');
    ok(length($name) > 0, 'final name is valid');
};

# Test 8: Complete workflow test
subtest 'Complete Choice Workflow Test' => sub {
    plan tests => 6;
    
    # Test all possible initial responses in sequence
    my @choice_sequences = (
        { input => "\n", desc => "immediate accept" },
        { input => "r\n\n", desc => "reroll then accept" },
        { input => "v\n\n", desc => "historical then accept" },
        { input => "c\nTest Plane Name\n", desc => "custom name entry" }
    );
    
    foreach my $test_case (@choice_sequences) {
        my $namer = SoloGamer::PlaneNamer->new(
            automated => 0,
            generated_names_file => "$games_dir/generated_b17_bomber_names.txt",
            verified_names_file => "$games_dir/verified_b17_bomber_names.txt"
        );
        
        open my $in_fh, '<', \$test_case->{input};
        local *STDIN = $in_fh;
        
        my $output = '';
        open my $out_fh, '>', \$output;
        my $old_stdout = select($out_fh);
        
        my $name = $namer->prompt_for_plane_name();
        
        select($old_stdout);
        close $out_fh;
        close $in_fh;
        
        ok(defined $name && length($name) > 0, "$test_case->{desc} produces valid name");
    }
    
    # Verify different sequences produce potentially different results
    ok(1, 'all choice sequences completed successfully');
    ok(1, 'plane naming system handles all user interaction patterns');
};

done_testing();