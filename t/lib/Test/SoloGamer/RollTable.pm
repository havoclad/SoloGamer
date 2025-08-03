package Test::SoloGamer::RollTable;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions

use lib '/perl';

extends 'Test::SoloGamer::Table';

sub test_roll_table_creation : Test(4) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    # Create test roll table data
    my $roll_data = {
        'dice' => '2d6',
        'options' => [
            {'result' => [2,7], 'text' => 'Low roll'},
            {'result' => [8,12], 'text' => 'High roll'}
        ]
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table is RollTable');
    isa_ok($table, 'SoloGamer::Table', 'RollTable extends Table');
    
    # Test that dice data is preserved
    is($table->data->{dice}, '2d6', 'dice data preserved');
    isa_ok($table->data->{options}, 'ARRAY', 'options is array');
}

sub test_roll_table_attributes : Test(5) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_roll_table($roll_data, {
        rolltype => 'damage',
        determines => 'hit_location',
        group_by => 'target'
    });
    
    # Test optional attributes
    is($table->rolltype, 'damage', 'rolltype attribute set');
    is($table->determines, 'hit_location', 'determines attribute set');
    is($table->group_by, 'target', 'group_by attribute set');
    
    # Test default attributes
    isa_ok($table->modifiers, 'ARRAY', 'modifiers is array');
    is(scalar @{$table->modifiers}, 0, 'modifiers defaults to empty array');
}

sub test_roll_table_group_by_default : Test(1) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    # Create table without specifying group_by
    my $table = $test->create_test_roll_table($roll_data);
    
    # Test that group_by defaults to 'join'
    is($table->group_by, 'join', 'group_by defaults to join');
}

sub test_roll_table_scope_attribute : Test(2) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    # Test scope attribute (lazy built)
    can_ok($table, 'scope', 'table has scope method');
    
    # Test that scope is read-write
    my $original_scope = $table->scope;
    $table->scope('new_scope');
    is($table->scope, 'new_scope', 'scope is read-write');
}

sub test_roll_table_rolls_attribute : Test(2) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    # Test rolls attribute (lazy built)
    can_ok($table, 'rolls', 'table has rolls method');
    isa_ok($table->rolls, 'HASH', 'rolls is a hash reference');
}

sub test_roll_table_with_complex_options : Test(3) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    # Create table with complex options structure
    my $roll_data = {
        'dice' => '2d6',
        'options' => [
            {
                'result' => [2,3],
                'text' => 'Critical failure',
                'next' => 'damage-table',
                'set' => {'damage' => 'severe'}
            },
            {
                'result' => [4,10],
                'text' => 'Normal result',
                'only_if' => '$target_type == "fighter"'
            },
            {
                'result' => [11,12],
                'text' => 'Critical success',
                'next' => 'success-table'
            }
        ]
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table created with complex options');
    is(scalar @{$table->data->{options}}, 3, 'all options preserved');
    
    # Test that option structure is preserved
    my $first_option = $table->data->{options}->[0];
    is($first_option->{text}, 'Critical failure', 'option text preserved');
}

sub test_roll_table_inheritance : Test(3) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    # Test inheritance chain
    isa_ok($table, 'SoloGamer::Table', 'RollTable extends Table');
    isa_ok($table, 'SoloGamer::Base', 'RollTable inherits from Base');
    
    # Test that inherited methods are available
    can_ok($table, 'devel', 'RollTable has Logger methods');
}

sub test_roll_table_required_data : Test(2) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    # Test that dice is typically required for roll tables
    my $minimal_data = {
        'options' => []
    };
    
    # This might not fail at construction but would fail during operation
    # We're testing that the table can be created with minimal data
    my $table = $test->create_test_roll_table($minimal_data);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table created with minimal data');
    
    # Test that options is preserved even when empty
    isa_ok($table->data->{options}, 'ARRAY', 'options array preserved');
}

sub test_roll_table_modifiers_default : Test(2) {
    my $test = shift;
    
    require SoloGamer::RollTable;
    
    my $roll_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_roll_table($roll_data);
    
    # Test modifiers default
    isa_ok($table->modifiers, 'ARRAY', 'modifiers is array');
    is(scalar @{$table->modifiers}, 0, 'modifiers starts empty');
}

# Helper method to create a test roll table
sub create_test_roll_table {
    my ($test, $roll_data, $additional_attributes) = @_;
    
    require SoloGamer::RollTable;
    
    my $base_data = {
        'Title' => 'Test Roll Table',
        'table_type' => 'roll',
        %{$roll_data || {}}
    };
    
    my $temp_file = $test->create_temp_json_file($base_data);
    
    my %args = (
        data => $base_data,
        file => $temp_file,
        name => 'test-roll-table',
        Title => 'Test Roll Table',
        %{$additional_attributes || {}}
    );
    
    return SoloGamer::RollTable->new(%args);
}

1;