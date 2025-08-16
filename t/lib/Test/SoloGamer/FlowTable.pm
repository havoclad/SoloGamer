package Test::SoloGamer::FlowTable;

use v5.42;

use Test::Class::Moose;
use Test2::V0 qw(dies like);

use lib '/perl';

extends 'Test::SoloGamer::Table';

sub test_flow_table_creation : Test(4) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    # Create test flow table data
    my $flow_data = {
        'flow' => [
            {'type' => 'roll', 'dice' => '1d6'},
            {'type' => 'choice', 'options' => ['A', 'B']},
            {'pre' => 'Final step'}
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    isa_ok($table, 'SoloGamer::FlowTable', 'table is FlowTable');
    isa_ok($table, 'SoloGamer::Table', 'FlowTable extends Table');
    
    # Test that flow data is processed correctly
    isa_ok($table->flow, 'ARRAY', 'flow is array');
    is(scalar @{$table->flow}, 3, 'flow has correct number of steps');
}

sub test_flow_table_flow_attribute : Test(4) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [
            {'step' => 1, 'action' => 'roll dice'},
            {'step' => 2, 'action' => 'apply result'}
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test flow attribute
    isa_ok($table->flow, 'ARRAY', 'flow is array reference');
    is(scalar @{$table->flow}, 2, 'flow has correct number of items');
    
    # Test that flow data is extracted from main data
    ok(!exists $table->data->{flow}, 'flow removed from data after extraction');
    
    # Test flow content preservation
    is($table->flow->[0]->{step}, 1, 'flow content preserved correctly');
}

sub test_flow_table_current_attribute : Test(3) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [
            {'step' => 1},
            {'step' => 2}
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test current attribute defaults
    is($table->current, 0, 'current defaults to 0');
    
    # Test current is read-write
    $table->current(1);
    is($table->current, 1, 'current can be set');
    
    # Test current can be reset
    $table->current(0);
    is($table->current, 0, 'current can be reset');
}

sub test_get_next_method : Test(6) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [
            {'step' => 1, 'action' => 'first'},
            {'step' => 2, 'action' => 'second'},
            {'step' => 3, 'action' => 'third'}
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test initial state
    is($table->current, 0, 'starts at position 0');
    
    # Test first get_next call
    my $next1 = $table->get_next();
    is($table->current, 1, 'current incremented to 1');
    is($next1->{step}, 1, 'returns first flow item');
    
    # Test second get_next call
    my $next2 = $table->get_next();
    is($table->current, 2, 'current incremented to 2');
    is($next2->{step}, 2, 'returns second flow item');
    
    # Test third get_next call
    my $next3 = $table->get_next();
    is($next3->{step}, 3, 'returns third flow item');
}

sub test_get_next_end_of_flow : Test(3) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [
            {'step' => 1}
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Get the only item
    my $next1 = $table->get_next();
    is($next1->{step}, 1, 'returns the only flow item');
    is($table->current, 1, 'current is now 1');
    
    # Try to get next when at end
    my $next2 = $table->get_next();
    is($next2, undef, 'returns undef when past end of flow');
}

sub test_get_next_empty_flow : Test(2) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => []
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test empty flow
    is($table->current, 0, 'starts at position 0');
    
    my $next = $table->get_next();
    is($next, undef, 'returns undef for empty flow');
}

sub test_flow_table_inheritance : Test(3) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [{'step' => 1}]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test inheritance chain
    isa_ok($table, 'SoloGamer::Table', 'FlowTable extends Table');
    isa_ok($table, 'SoloGamer::Base', 'FlowTable inherits from Base');
    
    # Test that inherited methods are available
    can_ok($table, 'devel', 'FlowTable has Logger methods');
}

sub test_flow_table_type_constraints : Test(1) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    my $flow_data = {
        'flow' => [{'step' => 1}]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    # Test that current attribute has type constraint (NonNegativeInt)
    like(
        dies { $table->current(-1) },
        qr/type constraint/i,
        'current rejects negative values'
    );
}

sub test_flow_table_complex_flow : Test(3) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    # Create complex flow with different step types
    my $flow_data = {
        'flow' => [
            {
                'type' => 'choosemax',
                'variable' => 'Mission',
                'pre' => 'Rolling for Mission'
            },
            {
                'type' => 'roll',
                'dice' => '2d6',
                'table' => 'combat-table'
            },
            {
                'pre' => 'Mission complete',
                'next' => 'end-game'
            }
        ]
    };
    
    my $table = $test->create_test_flow_table($flow_data);
    
    isa_ok($table, 'SoloGamer::FlowTable', 'complex flow table created');
    is(scalar @{$table->flow}, 3, 'complex flow has all steps');
    
    # Test accessing complex flow steps
    my $first_step = $table->get_next();
    is($first_step->{type}, 'choosemax', 'complex flow step preserved');
}

sub test_flow_table_immutability : Test(1) {
    my $test = shift;
    
    require SoloGamer::FlowTable;
    
    # Test that the class is made immutable
    ok(SoloGamer::FlowTable->meta->is_immutable, 'SoloGamer::FlowTable is immutable');
}

# Helper method to create a test flow table
sub create_test_flow_table {
    my ($test, $flow_data) = @_;
    
    require SoloGamer::FlowTable;
    
    my $base_data = {
        'Title' => 'Test Flow Table',
        'table_type' => 'Flow',
        %{$flow_data || {}}
    };
    
    my $temp_file = $test->create_temp_json_file($base_data);
    
    return SoloGamer::FlowTable->new(
        data => $base_data,
        file => $temp_file,
        name => 'test-flow-table',
        Title => 'Test Flow Table'
    );
}

1;