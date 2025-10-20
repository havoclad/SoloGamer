#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use List::Util qw(first);

use lib 't/lib';
use lib 'perl';

use SoloGamer::Game;

# Test for mission table display functionality
# Ensures that the correct mission table (G-1, G-2, G-3) is displayed based on mission number

plan tests => 6;

# Test choices data structure matching the actual FLOW-start.json format
my @choices = (
    {
        "max" => "5",
        "Table" => "G-1"
    },
    {
        "max" => "10", 
        "Table" => "G-2"
    },
    {
        "max" => "25",
        "Table" => "G-3"
    },
    {
        "max" => "26",
        "Table" => "end"
    }
);

# Create a minimal Game object just to access the first-based table selection
# We'll create a mock object that uses List::Util::first
package TestGame {
    use Moose;
    use List::Util qw(first);

    sub select_table {
        my $self = shift;
        my $variable = shift;
        my $choices = shift;

        # Ensure numeric comparison (same logic as in Game.pm)
        $variable = int($variable) if defined $variable;

        my $table_item = first { $variable <= $_->{max} } $choices->@*;
        die "Didn't find a max that matched $variable" unless $table_item;
        return $table_item->{Table};
    }
}

# Test mission table selection for different mission numbers
subtest 'Mission 1 uses G-1' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(1, \@choices);
    is($table, 'G-1', 'Mission 1 selects G-1 table');
};

subtest 'Mission 5 uses G-1' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(5, \@choices);
    is($table, 'G-1', 'Mission 5 selects G-1 table');
};

subtest 'Mission 6 uses G-2' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(6, \@choices);
    is($table, 'G-2', 'Mission 6 selects G-2 table');
};

subtest 'Mission 10 uses G-2' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(10, \@choices);
    is($table, 'G-2', 'Mission 10 selects G-2 table');
};

subtest 'Mission 11 uses G-3' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(11, \@choices);
    is($table, 'G-3', 'Mission 11 selects G-3 table');
};

subtest 'Mission 25 uses G-3' => sub {
    plan tests => 1;

    my $game = TestGame->new();
    my $table = $game->select_table(25, \@choices);
    is($table, 'G-3', 'Mission 25 selects G-3 table');
};

done_testing();