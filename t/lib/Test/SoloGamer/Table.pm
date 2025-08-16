package Test::SoloGamer::Table;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions

use lib '/perl';

extends 'Test::SoloGamer::Base';

# This base class provides common tests for all table types
# Individual table type test classes will extend this

sub test_table_attributes : Test(6) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    # Create a test table with minimal required data
    my $test_data = {
        'Title' => 'Test Table',
        'pre' => 'Pre-table text',
        'type' => 'test'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    my $table = SoloGamer::Table->new(
        data => $test_data,
        file => $temp_file,
        name => 'test-table',
        Title => 'Test Table'
    );
    
    # Test required attributes
    isa_ok($table, 'SoloGamer::Table', 'table is correct type');
    isa_ok($table->data, 'HASH', 'data is a HashRef');
    is($table->file, $temp_file, 'file attribute is correct');
    is($table->name, 'test-table', 'name attribute is correct');
    is($table->title, 'Test Table', 'title attribute is correct');
    
    # Test that table extends SoloGamer::Base
    isa_ok($table, 'SoloGamer::Base', 'table extends SoloGamer::Base');
}

sub test_pre_attribute_with_data : Test(2) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    # Create table data with 'pre' field
    my $test_data = {
        'Title' => 'Test Table',
        'pre' => 'Pre-table text',
        'type' => 'test'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    my $table = SoloGamer::Table->new(
        data => $test_data,
        file => $temp_file,
        name => 'test-table',
        Title => 'Test Table'
    );
    
    # Test that pre is extracted from data
    is($table->pre, 'Pre-table text', 'pre attribute extracts from data');
    
    # Test that pre is removed from data during construction
    ok(!exists $table->data->{pre}, 'pre is removed from data after extraction');
}

sub test_pre_attribute_without_data : Test(1) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    # Create table data without 'pre' field
    my $test_data = {
        'Title' => 'Test Table',
        'type' => 'test'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    my $table = SoloGamer::Table->new(
        data => $test_data,
        file => $temp_file,
        name => 'test-table',
        Title => 'Test Table'
    );
    
    # Test that pre defaults to empty string when not in data
    is($table->pre, '', 'pre defaults to empty string when not in data');
}

sub test_table_inheritance : Test(2) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    my $test_data = {
        'Title' => 'Test Table',
        'type' => 'test'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    my $table = SoloGamer::Table->new(
        data => $test_data,
        file => $temp_file,
        name => 'test-table',
        Title => 'Test Table'
    );
    
    # Test inheritance from SoloGamer::Base
    isa_ok($table, 'SoloGamer::Base', 'table inherits from SoloGamer::Base');
    
    # Test that Logger role is available through inheritance
    can_ok($table, 'devel', 'table has Logger role methods through inheritance');
}

sub test_table_required_attributes : Test(4) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    my $test_data = {
        'Title' => 'Test Table',
        'type' => 'test'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    # Test that all required attributes must be provided
    
    # Missing data should fail
    like(
        dies { SoloGamer::Table->new(
            file => $temp_file,
            name => 'test-table',
            Title => 'Test Table'
        ) },
        qr/required/i,
        'data is required'
    );
    
    # Missing file should fail
    like(
        dies { SoloGamer::Table->new(
            data => $test_data,
            name => 'test-table',
            Title => 'Test Table'
        ) },
        qr/required/i,
        'file is required'
    );
    
    # Missing name should fail
    like(
        dies { SoloGamer::Table->new(
            data => $test_data,
            file => $temp_file,
            Title => 'Test Table'
        ) },
        qr/required/i,
        'name is required'
    );
    
    # Missing title should fail
    like(
        dies { SoloGamer::Table->new(
            data => $test_data,
            file => $temp_file,
            name => 'test-table'
        ) },
        qr/required/i,
        'title is required'
    );
}

sub test_table_immutability : Test(1) {
    my $test = shift;
    
    require SoloGamer::Table;
    
    # Test that the class is made immutable
    ok(SoloGamer::Table->meta->is_immutable, 'SoloGamer::Table is immutable');
}

# Helper method for subclasses to create a basic table for testing
sub create_test_table {
    my ($test, $additional_data) = @_;
    
    require SoloGamer::Table;
    
    my $test_data = {
        'Title' => 'Test Table',
        'type' => 'test',
        %{$additional_data || {}}
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    return SoloGamer::Table->new(
        data => $test_data,
        file => $temp_file,
        name => 'test-table',
        Title => 'Test Table'
    );
}

1;