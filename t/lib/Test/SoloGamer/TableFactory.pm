package Test::SoloGamer::TableFactory;

use v5.42;

use Test::Class::Moose;
use Test2::V0 qw(dies like);
use File::Temp;

use lib '/perl';

extends 'Test::SoloGamer::Base';

sub test_table_factory_attributes : Test(3) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    # Test default construction
    my $factory = SoloGamer::TableFactory->new();
    
    isa_ok($factory, 'SoloGamer::TableFactory', 'factory is correct type');
    isa_ok($factory, 'SoloGamer::Base', 'factory extends SoloGamer::Base');
    
    # Test automated attribute default
    is($factory->automated, 0, 'automated defaults to 0');
}

sub test_table_factory_with_automated : Test(1) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    # Test construction with automated parameter
    my $factory = SoloGamer::TableFactory->new(automated => 1);
    
    is($factory->automated, 1, 'automated can be set to 1');
}

sub test_load_json_file : Test(3) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create test JSON data
    my $test_data = {
        'Title' => 'Test Table',
        'table_type' => 'roll',
        'dice' => '1d6'
    };
    
    my $temp_file = $test->create_temp_json_file($test_data);
    
    # Test loading JSON file
    my $loaded_data = $factory->load_json_file($temp_file);
    
    isa_ok($loaded_data, 'HASH', 'loaded data is a hash reference');
    is($loaded_data->{Title}, 'Test Table', 'JSON data loaded correctly');
    is($loaded_data->{table_type}, 'roll', 'JSON data structure preserved');
}

sub test_load_json_file_invalid : Test(1) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Test loading non-existent file
    like(
        dies { $factory->load_json_file('/nonexistent/file.json') },
        qr/./,
        'load_json_file dies on non-existent file'
    );
}

sub test_new_table_flow_type : Test(4) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create Flow table JSON
    my $flow_data = {
        'Title' => 'Test Flow Table',
        'table_type' => 'Flow',
        'flow' => [
            {'type' => 'roll', 'dice' => '1d6'}
        ]
    };
    
    my $temp_file = $test->create_temp_json_file($flow_data);
    
    # Test creating Flow table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::FlowTable', 'creates FlowTable for Flow type');
    isa_ok($table, 'SoloGamer::Table', 'FlowTable inherits from Table');
    is($table->name, 'Test Flow Table', 'table name set correctly from filename');
    is($table->title, 'Test Flow Table', 'table title set correctly');
}

sub test_new_table_roll_type : Test(3) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create Roll table JSON
    my $roll_data = {
        'Title' => 'Test Roll Table',
        'table_type' => 'roll',
        'dice' => '2d6',
        'options' => [
            {'result' => [2,12], 'text' => 'Test result'}
        ]
    };
    
    my $temp_file = $test->create_temp_json_file($roll_data);
    
    # Test creating Roll table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::RollTable', 'creates RollTable for roll type');
    isa_ok($table, 'SoloGamer::Table', 'RollTable inherits from Table');
    is($table->title, 'Test Roll Table', 'table title set correctly');
}

sub test_new_table_onlyif_type : Test(3) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create OnlyIf table JSON
    my $onlyif_data = {
        'Title' => 'Test OnlyIf Table',
        'table_type' => 'onlyif',
        'variable_to_test' => 'test_var',
        'test_criteria' => 'eq',
        'test_against' => 'test_value',
        'dice' => '1d6'
    };
    
    my $temp_file = $test->create_temp_json_file($onlyif_data);
    
    # Test creating OnlyIf table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::OnlyIfRollTable', 'creates OnlyIfRollTable for onlyif type');
    isa_ok($table, 'SoloGamer::Table', 'OnlyIfRollTable inherits from Table');
    is($table->title, 'Test OnlyIf Table', 'table title set correctly');
}

sub test_new_table_invalid_type : Test(1) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create table with invalid type
    my $invalid_data = {
        'Title' => 'Invalid Table',
        'table_type' => 'invalid_type'
    };
    
    my $temp_file = $test->create_temp_json_file($invalid_data);
    
    # Test that invalid table type throws error
    like(
        dies { $factory->new_table($temp_file) },
        qr/table_type of invalid_type/,
        'new_table dies on invalid table type'
    );
}

sub test_new_table_attribute_extraction : Test(5) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create table with various attributes that should be extracted
    my $table_data = {
        'Title' => 'Attribute Test Table',
        'table_type' => 'roll',
        'dice' => '1d6',
        'group_by' => 'test_group',
        'rolltype' => 'test_roll',
        'determines' => 'test_determines',
        'variable_to_test' => 'test_var',
        'test_criteria' => 'eq',
        'test_against' => 'value',
        'fail_message' => 'Test failure',
        'options' => []
    };
    
    my $temp_file = $test->create_temp_json_file($table_data);
    
    # Test creating table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table created successfully');
    
    # Test that extracted attributes are not in data
    ok(!exists $table->data->{Title}, 'Title extracted from data');
    ok(!exists $table->data->{table_type}, 'table_type extracted from data');
    ok(!exists $table->data->{group_by}, 'group_by extracted from data');
    
    # Test that remaining data is preserved
    ok(exists $table->data->{options}, 'non-extracted data preserved');
}

sub test_new_table_automated_parameter : Test(2) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new(automated => 1, verbose => 1);
    
    # Create simple table
    my $table_data = {
        'Title' => 'Automated Test Table',
        'table_type' => 'roll',
        'dice' => '1d6'
    };
    
    my $temp_file = $test->create_temp_json_file($table_data);
    
    # Test creating table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table created with automated factory');
    
    # Test that automated and verbose are passed to table
    # Note: We'll need to check if these are accessible on the table
    # This might require extending the table classes to expose these attributes
    can_ok($table, 'automated', 'table has automated method if implemented');
}

sub test_new_table_filename_parsing : Test(2) {
    my $test = shift;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Create table data
    my $table_data = {
        'Title' => 'Filename Test Table',
        'table_type' => 'roll',
        'dice' => '1d6'
    };
    
    # Create temp file with specific name
    my $fh = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json',
        TEMPLATE => 'test-table-XXXX',
        UNLINK => 0
    );
    
    require Mojo::JSON;
    print $fh Mojo::JSON::encode_json($table_data);
    close $fh;
    
    my $temp_file = $fh->filename;
    
    # Test creating table
    my $table = $factory->new_table($temp_file);
    
    isa_ok($table, 'SoloGamer::RollTable', 'table created successfully');
    
    # Test that filename is parsed correctly (removes path and .json extension)
    like($table->name, qr/test-table-/, 'table name parsed from filename');
}

1;