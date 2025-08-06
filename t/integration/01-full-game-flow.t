#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;
use Test2::Tools::Exception qw(lives dies);
use File::Temp;
use File::Path qw(make_path);

use lib 't/lib';
use lib 'perl';

use TestFixture::GameData qw(sample_complete_game_data sample_game_save_data);

# Integration test for full game flow
# This tests the interaction between Game, SaveGame, TableFactory, and various table types

plan tests => 10;

# Create temporary directory structure for the test
my $temp_dir = File::Temp->newdir();
my $games_dir = "$temp_dir/games/TestGame/data";
make_path($games_dir);

# Create test game data files
my $game_data = sample_complete_game_data();

foreach my $table_name (keys %$game_data) {
    my $file_path = "$games_dir/$table_name.json";
    
    require Mojo::JSON;
    open my $fh, '>', $file_path or die "Cannot create $file_path: $!";
    print $fh Mojo::JSON::encode_json($game_data->{$table_name});
    close $fh;
}

# Create test save file
my $save_data = sample_game_save_data();
my $save_file = "$temp_dir/test_save.json";

require Mojo::JSON;
open my $save_fh, '>', $save_file or die "Cannot create $save_file: $!";
print $save_fh Mojo::JSON::encode_json($save_data);
close $save_fh;

# Test 1: TableFactory can load and create all table types
subtest 'TableFactory Integration' => sub {
    plan tests => 6;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new(automated => 1);
    
    # Test loading different table types
    my $combat_table = $factory->new_table("$games_dir/combat_table.json");
    isa_ok($combat_table, ['SoloGamer::RollTable'], 'combat table is RollTable');
    
    my $damage_table = $factory->new_table("$games_dir/damage_table.json");
    isa_ok($damage_table, ['SoloGamer::RollTable'], 'damage table is RollTable');
    
    my $mission_flow = $factory->new_table("$games_dir/mission_flow.json");
    isa_ok($mission_flow, ['SoloGamer::FlowTable'], 'mission flow is FlowTable');
    
    # Test table data integrity
    is($combat_table->title, 'Air Combat Resolution', 'combat table title correct');
    is($damage_table->title, 'Aircraft Damage', 'damage table title correct');
    is($mission_flow->title, 'Mission Sequence', 'mission flow title correct');
};

# Test 2: SaveGame can load and manage save data
subtest 'SaveGame Integration' => sub {
    plan tests => 4;
    
    require SoloGamer::SaveGame;
    
    # Clear any existing instance
    if (SoloGamer::SaveGame->can('_clear_instance')) {
        SoloGamer::SaveGame->_clear_instance();
    }
    
    my $save_game = SoloGamer::SaveGame->initialize(save_file => $save_file);
    $save_game->load_save();
    
    # Test save data loading
    is(ref($save_game->save), 'HASH', 'save data is hash');
    is($save_game->save->{game_name}, 'B-17 Queen of the Skies', 'game name loaded correctly');
    
    # Test mission calculation
    is($save_game->mission, 3, 'next mission calculated correctly');
    
    # Test save data structure
    is(scalar @{$save_game->save->{mission}}, 2, 'mission history loaded correctly');
};

# Test 3: Game object integration
subtest 'Game Integration' => sub {
    plan tests => 5;
    
    require SoloGamer::Game;
    
    # Mock the game directory structure by setting environment or using minimal requirements
    my $game = SoloGamer::Game->new(
        name => 'TestGame',
        save_file => $save_file,
        automated => 1,
        use_color => 0
    );
    
    isa_ok($game, ['SoloGamer::Game'], 'game object created');
    isa_ok($game, ['SoloGamer::Base'], 'game inherits from Base');
    
    # Test game attributes
    is($game->name, 'TestGame', 'game name set correctly');
    ok($game->automated, 'automated mode enabled');
    ok(!$game->use_color, 'color disabled');
};

# Test 4: Table inheritance and role composition
subtest 'Table Inheritance Chain' => sub {
    plan tests => 9;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    my $roll_table = $factory->new_table("$games_dir/combat_table.json");
    
    # Test inheritance chain
    isa_ok($roll_table, ['SoloGamer::RollTable'], 'is RollTable');
    isa_ok($roll_table, ['SoloGamer::Table'], 'inherits from Table');
    isa_ok($roll_table, ['SoloGamer::Base'], 'inherits from Base');
    
    # Test role composition
    can_ok($roll_table, ['devel'], 'has Logger role methods');
    can_ok($roll_table, ['verbose'], 'has verbose from Logger');
    
    # Test table-specific methods
    can_ok($roll_table, ['rolltype'], 'has RollTable-specific methods');
    can_ok($roll_table, ['determines'], 'has determines attribute');
    
    # Test data integrity
    is($roll_table->data->{dice}, '2d6', 'dice data preserved');
    is(scalar @{$roll_table->data->{options}}, 3, 'options preserved');
};

# Test 5: FlowTable specific functionality
subtest 'FlowTable Integration' => sub {
    plan tests => 7;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    my $flow_table = $factory->new_table("$games_dir/mission_flow.json");
    
    isa_ok($flow_table, ['SoloGamer::FlowTable'], 'is FlowTable');
    
    # Test flow navigation
    is($flow_table->current, 0, 'starts at position 0');
    
    my $first_step = $flow_table->get_next();
    ok(defined $first_step, 'first step retrieved');
    is($flow_table->current, 1, 'current incremented after first get_next');
    ok(exists $first_step->{pre} && $first_step->{pre} eq 'Takeoff and formation', 'first step has correct content');
    
    my $second_step = $flow_table->get_next();
    ok(defined $second_step, 'second step retrieved');
    is($second_step->{type}, 'roll', 'second step has correct type');
};

# Test 6: Complex table options processing
subtest 'Table Options Processing' => sub {
    plan tests => 4;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    my $combat_table = $factory->new_table("$games_dir/combat_table.json");
    
    # Test option structure
    my $options = $combat_table->data->{options};
    is(ref($options), 'ARRAY', 'options is array');
    is(scalar @$options, 3, 'has correct number of options');
    
    # Test option content
    my $first_option = $options->[0];
    is(ref($first_option->{result}), 'ARRAY', 'result is array');
    ok(exists $first_option->{set}, 'option has set directive');
};

# Test 7: Error handling and edge cases
subtest 'Error Handling' => sub {
    plan tests => 3;
    
    require SoloGamer::TableFactory;
    
    my $factory = SoloGamer::TableFactory->new();
    
    # Test nonexistent file
    like(
        dies { $factory->new_table("/nonexistent/file.json") },
        qr/./,
        'dies on nonexistent file'
    );
    
    # Test SaveGame with nonexistent save file
    require SoloGamer::SaveGame;
    SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
    
    my $save_game = SoloGamer::SaveGame->initialize(save_file => "/nonexistent/save.json", automated => 1);
    
    ok(lives { $save_game->load_save() }, 'SaveGame handles nonexistent save file');
    is($save_game->mission, 1, 'mission defaults to 1 for new save');
};

# Test 8: BufferedOutput integration
subtest 'BufferedOutput Integration' => sub {
    plan tests => 4;
    
    require SoloGamer::Game;
    
    my $game = SoloGamer::Game->new(
        name => 'BufferTestGame',
        automated => 1
    );
    
    # Test buffer functionality
    $game->buffer('Test message 1');
    $game->buffer('Test message 2');
    
    is(scalar @{$game->buffered_output}, 2, 'buffer stores messages');
    
    # Test formatted buffer methods
    $game->buffer_success('Success message');
    is(scalar @{$game->buffered_output}, 3, 'formatted buffer methods work');
    
    # Test buffer clearing
    $game->flush();
    is(scalar @{$game->buffered_output}, 0, 'flush clears buffer');
    
    # Test formatter exists
    isa_ok($game->formatter, ['SoloGamer::Formatter'], 'formatter is correct type');
};

# Test 9: Type constraints and validation
subtest 'Type Constraints' => sub {
    plan tests => 3;
    
    require SoloGamer::SaveGame;
    require SoloGamer::FlowTable;
    require SoloGamer::TableFactory;
    
    # Test PositiveInt constraint on SaveGame
    SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
    my $save_game = SoloGamer::SaveGame->instance();
    
    like(
        dies { $save_game->mission(0) },
        qr/type constraint/i,
        'SaveGame mission rejects zero'
    );
    
    # Test NonNegativeInt constraint on FlowTable
    my $factory = SoloGamer::TableFactory->new();
    my $flow_table = $factory->new_table("$games_dir/mission_flow.json");
    
    like(
        dies { $flow_table->current(-1) },
        qr/type constraint/i,
        'FlowTable current rejects negative values'
    );
    
    # Test that valid values work
    ok(lives { $flow_table->current(5) }, 'FlowTable accepts valid current value');
};

# Test 10: Memory and cleanup
subtest 'Memory and Cleanup' => sub {
    plan tests => 2;
    
    require SoloGamer::SaveGame;
    
    # Test singleton cleanup
    SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
    
    my $save1 = SoloGamer::SaveGame->instance();
    my $addr1 = "$save1";  # String representation includes memory address
    
    SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
    
    my $save2 = SoloGamer::SaveGame->instance();
    my $addr2 = "$save2";
    
    isnt($addr1, $addr2, 'singleton instance can be cleared and recreated');
    
    # Test that new instance works correctly
    isa_ok($save2, ['SoloGamer::SaveGame'], 'new instance is correct type');
};

done_testing();