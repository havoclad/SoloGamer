#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;

use lib 't/lib';
use lib 'perl';

plan tests => 4;

# Test command-line parsing and parameter passing for --input_file option

# Test 1: Help output includes --input_file option
subtest 'Help output includes input_file option' => sub {
    plan tests => 1;
    
    # Read the script directly to check help text
    my $script_path = -f 'perl/SoloGamer.pl' ? 'perl/SoloGamer.pl' : '/perl/SoloGamer.pl';
    open my $fh, '<', $script_path or skip_all "Cannot read SoloGamer.pl at $script_path";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    like($content, qr/--input_file=FILE.*Read user inputs from file/, 
         'Help text includes input_file option description');
};

# Test 2: Script accepts --input_file parameter without error
subtest 'Script accepts input_file parameter' => sub {
    plan tests => 1;
    
    # Test argument parsing directly via GetOptions
    require SoloGamer::Game;
    
    # Create a temporary input file
    my $input_file = File::Temp->new();
    print $input_file "accept\naccept\n";
    close $input_file;
    
    # Test that Game object can be created with input_file parameter
    my $game = eval {
        SoloGamer::Game->new_game(
            name       => 'QotS',
            verbose    => 0,
            save_file  => '',
            automated  => 1,
            use_color  => 0,
            input_file => $input_file->filename,
        );
    };
    
    ok($game, 'Game object created successfully with input_file parameter');
};

# Test 3: Invalid input_file parameter is handled gracefully
subtest 'Invalid input_file shows error' => sub {
    plan tests => 1;
    
    # Test that trying to use a non-existent input file fails appropriately
    require SoloGamer::QotS::PlaneNamer;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        input_file => '/nonexistent/file.txt',
        generated_names_file => '/games/QotS/generated_b17_bomber_names.txt',
        verified_names_file => '/games/QotS/verified_b17_bomber_names.txt'
    );
    
    # This should die when trying to open the non-existent file
    like(
        dies { $namer->prompt_for_plane_name() },
        qr/Cannot open input file.*nonexistent.*file\.txt/,
        'Dies with helpful error for non-existent input file'
    );
};

# Test 4: Game class receives input_file parameter
subtest 'Game class parameter passing' => sub {
    plan tests => 3;
    
    require SoloGamer::Game;
    
    my $input_file = File::Temp->new();
    close $input_file;
    
    my $game = SoloGamer::Game->new_game(
        name       => 'QotS',
        verbose    => 0,
        save_file  => '',
        automated  => 1,
        use_color  => 0,
        input_file => $input_file->filename,
    );
    
    ok(defined $game, 'Game object created with input_file parameter');
    is($game->input_file, $input_file->filename, 'Game object stores input_file parameter');
    ok($game->can('input_file'), 'Game object has input_file accessor');
};

done_testing();