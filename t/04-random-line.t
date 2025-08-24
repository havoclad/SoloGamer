#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);

use lib 't/lib';
use lib 'perl';

# Load the module we're testing
use HavocLad::File::RandomLine qw(random_line);

# Test 1: Basic functionality - returns a line from file
subtest 'Basic functionality' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "line1\nline2\nline3\n");
    
    my $result = random_line($filename);
    ok($result, 'Got a result from random_line');
    like($result, qr/^line[123]$/x, 'Result is one of the expected lines');
};

# Test 2: Filters out empty lines
subtest 'Filters empty lines' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "line1\n\n  \nline2\n\t\nline3\n   \n");
    
    my $result = random_line($filename);
    ok($result, 'Got a result despite empty lines');
    like($result, qr/^line[123]$/x, 'Result is a non-empty line');
    
    # Run multiple times to ensure we never get empty lines
    for (1..10) {
        my $res = random_line($filename);
        unlike($res, qr/^\s*$/x, 'Never returns empty or whitespace-only lines');
    }
};

# Test 3: Single valid line
subtest 'Single line file' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "only_line\n");
    
    my $result = random_line($filename);
    is($result, 'only_line', 'Returns the only line available');
    
    # Should always return the same line
    for (1..5) {
        is(random_line($filename), 'only_line', 'Consistently returns single line');
    }
};

# Test 4: Single valid line with empty lines
subtest 'Single valid line with empty lines' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "\n\n  \nvalid_line\n\t\n   \n");
    
    my $result = random_line($filename);
    is($result, 'valid_line', 'Returns the only valid line');
};

# Test 5: Randomness check (statistical test)
subtest 'Randomness' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "A\nB\nC\nD\nE\n");
    
    my %counts;
    my $iterations = 100;
    
    for (1..$iterations) {
        my $result = random_line($filename);
        $counts{$result}++;
    }
    
    # All lines should appear at least once in 100 iterations (statistically very likely)
    ok(keys %counts >= 3, 'At least 3 different lines returned in 100 iterations');
    
    # Check that we got valid lines
    for my $line (keys %counts) {
        like($line, qr/^[ABCDE]$/x, "Got valid line: $line");
    }
};

# Test 6: File with only empty lines (should die)
subtest 'File with only empty lines' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "\n\n  \n\t\n   \n");
    
    like(
        dies { random_line($filename) },
        qr/Nothing found in file/,
        'Dies with appropriate message for file with only empty lines'
    );
};

# Test 7: Non-existent file (should die)
subtest 'Non-existent file' => sub {
    my $fake_file = '/tmp/this_file_should_not_exist_' . $$ . '_' . time();
    
    like(
        dies { random_line($fake_file) },
        qr/open/i,
        'Dies when file does not exist'
    );
};

# Test 8: Empty file (should die)
subtest 'Empty file' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, '');
    
    like(
        dies { random_line($filename) },
        qr/Nothing found in file/,
        'Dies with appropriate message for empty file'
    );
};

# Test 9: Lines with various whitespace
subtest 'Lines with various whitespace' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    write_file($filename, "  leading\ntrailing  \n  both  \nnormal\n");
    
    my %seen;
    for (1..20) {
        my $result = random_line($filename);
        $seen{$result} = 1;
    }
    
    # Should get all non-empty lines (with their whitespace preserved)
    ok(exists $seen{'  leading'}, 'Gets line with leading whitespace');
    ok(exists $seen{'trailing  '}, 'Gets line with trailing whitespace');
    ok(exists $seen{'  both  '}, 'Gets line with both leading and trailing whitespace');
    ok(exists $seen{'normal'}, 'Gets normal line');
};

# Test 10: Large file performance (basic check)
subtest 'Large file handling' => sub {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    
    # Create a file with 1000 lines
    my @lines = map { "line_$_" } 1..1000;
    write_file($filename, join("\n", @lines) . "\n");
    
    my $result = random_line($filename);
    ok($result, 'Can handle large file');
    like($result, qr/^line_\d+$/x, 'Returns valid line from large file');
};

done_testing();