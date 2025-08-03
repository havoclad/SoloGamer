package Test::SoloGamer::OnlyIfRollTable;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions

use lib '/perl';

extends 'Test::SoloGamer::Table';

sub test_onlyif_table_creation : Test(5) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    # Create test onlyif table data
    my $onlyif_data = {
        'dice' => '1d6',
        'options' => [
            {'result' => [1,6], 'text' => 'Test result'}
        ]
    };
    
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'test_var',
        test_criteria => 'eq',
        test_against => 'test_value',
        fail_message => 'Test failed'
    });
    
    isa_ok($table, 'SoloGamer::OnlyIfRollTable', 'table is OnlyIfRollTable');
    isa_ok($table, 'SoloGamer::RollTable', 'OnlyIfRollTable extends RollTable');
    isa_ok($table, 'SoloGamer::Table', 'OnlyIfRollTable inherits from Table');
    
    # Test that dice data is preserved
    is($table->data->{dice}, '1d6', 'dice data preserved');
    isa_ok($table->data->{options}, 'ARRAY', 'options is array');
}

sub test_onlyif_table_required_attributes : Test(4) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $onlyif_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'health',
        test_criteria => '>',
        test_against => '0',
        fail_message => 'Not enough health'
    });
    
    # Test required attributes
    is($table->variable_to_test, 'health', 'variable_to_test set correctly');
    is($table->test_criteria, '>', 'test_criteria set correctly');
    is($table->test_against, '0', 'test_against set correctly');
    is($table->fail_message, 'Not enough health', 'fail_message set correctly');
}

sub test_onlyif_table_missing_required_attributes : Test(4) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $base_data = {
        'Title' => 'Test OnlyIf Table',
        'dice' => '1d6',
        'options' => []
    };
    
    my $temp_file = $test->create_temp_json_file($base_data);
    
    # Test that all required attributes must be provided
    
    # Missing variable_to_test should fail
    like(
        dies { SoloGamer::OnlyIfRollTable->new(
            data => $base_data,
            file => $temp_file,
            name => 'test-table',
            Title => 'Test OnlyIf Table',
            test_criteria => 'eq',
            test_against => 'value',
            fail_message => 'Failed'
        ) },
        qr/required/i,
        'variable_to_test is required'
    );
    
    # Missing test_criteria should fail
    like(
        dies { SoloGamer::OnlyIfRollTable->new(
            data => $base_data,
            file => $temp_file,
            name => 'test-table',
            Title => 'Test OnlyIf Table',
            variable_to_test => 'var',
            test_against => 'value',
            fail_message => 'Failed'
        ) },
        qr/required/i,
        'test_criteria is required'
    );
    
    # Missing test_against should fail
    like(
        dies { SoloGamer::OnlyIfRollTable->new(
            data => $base_data,
            file => $temp_file,
            name => 'test-table',
            Title => 'Test OnlyIf Table',
            variable_to_test => 'var',
            test_criteria => 'eq',
            fail_message => 'Failed'
        ) },
        qr/required/i,
        'test_against is required'
    );
    
    # Missing fail_message should fail
    like(
        dies { SoloGamer::OnlyIfRollTable->new(
            data => $base_data,
            file => $temp_file,
            name => 'test-table',
            Title => 'Test OnlyIf Table',
            variable_to_test => 'var',
            test_criteria => 'eq',
            test_against => 'value'
        ) },
        qr/required/i,
        'fail_message is required'
    );
}

sub test_onlyif_table_inheritance_from_roll_table : Test(6) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $onlyif_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'test_var',
        test_criteria => 'eq',
        test_against => 'test_value',
        fail_message => 'Test failed',
        rolltype => 'damage',
        determines => 'hit_location'
    });
    
    # Test inheritance chain
    isa_ok($table, 'SoloGamer::RollTable', 'OnlyIfRollTable extends RollTable');
    isa_ok($table, 'SoloGamer::Table', 'OnlyIfRollTable inherits from Table');
    isa_ok($table, 'SoloGamer::Base', 'OnlyIfRollTable inherits from Base');
    
    # Test that inherited attributes are available
    can_ok($table, 'rolltype', 'OnlyIfRollTable has RollTable attributes');
    can_ok($table, 'determines', 'OnlyIfRollTable has determines attribute');
    can_ok($table, 'devel', 'OnlyIfRollTable has Logger methods');
}

sub test_onlyif_table_with_roll_table_attributes : Test(3) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $onlyif_data = {
        'dice' => '2d6',
        'options' => []
    };
    
    # Create OnlyIf table with RollTable attributes
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'ammo',
        test_criteria => '>',
        test_against => '0',
        fail_message => 'Out of ammunition',
        rolltype => 'attack',
        determines => 'damage',
        group_by => 'weapon'
    });
    
    # Test that RollTable attributes work
    is($table->rolltype, 'attack', 'rolltype inherited from RollTable');
    is($table->determines, 'damage', 'determines inherited from RollTable');
    is($table->group_by, 'weapon', 'group_by inherited from RollTable');
}

sub test_onlyif_table_different_test_criteria : Test(5) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $onlyif_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    # Test different test criteria values
    my @criteria = ('>', '<', 'eq', '>=', '<=');
    
    foreach my $criteria (@criteria) {
        my $table = $test->create_test_onlyif_table($onlyif_data, {
            variable_to_test => 'test_var',
            test_criteria => $criteria,
            test_against => '5',
            fail_message => "Failed $criteria test"
        });
        
        is($table->test_criteria, $criteria, "test_criteria '$criteria' set correctly");
    }
}

sub test_onlyif_table_roll_method_exists : Test(1) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $onlyif_data = {
        'dice' => '1d6',
        'options' => []
    };
    
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'test_var',
        test_criteria => 'eq',
        test_against => 'test_value',
        fail_message => 'Test failed'
    });
    
    # Test that roll method is available (overridden from RollTable)
    can_ok($table, 'roll', 'OnlyIfRollTable has roll method');
}

sub test_onlyif_table_complex_scenario : Test(4) {
    my $test = shift;
    
    require SoloGamer::OnlyIfRollTable;
    
    # Create complex OnlyIf table with realistic game data
    my $onlyif_data = {
        'dice' => '2d6',
        'options' => [
            {
                'result' => [2,6],
                'text' => 'Miss',
                'next' => 'end-turn'
            },
            {
                'result' => [7,12],
                'text' => 'Hit',
                'next' => 'damage-table',
                'set' => {'hit' => 'true'}
            }
        ]
    };
    
    my $table = $test->create_test_onlyif_table($onlyif_data, {
        variable_to_test => 'ammunition',
        test_criteria => '>',
        test_against => '0',
        fail_message => 'No ammunition remaining',
        rolltype => 'combat',
        determines => 'hit_result'
    });
    
    isa_ok($table, 'SoloGamer::OnlyIfRollTable', 'complex OnlyIf table created');
    is(scalar @{$table->data->{options}}, 2, 'complex options preserved');
    is($table->variable_to_test, 'ammunition', 'complex variable_to_test set');
    is($table->rolltype, 'combat', 'complex rolltype set');
}

# Helper method to create a test onlyif table
sub create_test_onlyif_table {
    my ($test, $onlyif_data, $attributes) = @_;
    
    require SoloGamer::OnlyIfRollTable;
    
    my $base_data = {
        'Title' => 'Test OnlyIf Table',
        'table_type' => 'onlyif',
        %{$onlyif_data || {}}
    };
    
    my $temp_file = $test->create_temp_json_file($base_data);
    
    my %args = (
        data => $base_data,
        file => $temp_file,
        name => 'test-onlyif-table',
        Title => 'Test OnlyIf Table',
        %{$attributes || {}}
    );
    
    return SoloGamer::OnlyIfRollTable->new(%args);
}

1;