package Test::SoloGamer::SaveGame;

use v5.42;

use Test::Class::Moose;
use Test2::V0 qw(dies like);
use File::Temp;

use lib '/perl';

extends 'Test::SoloGamer::Base';

sub test_startup {
    my $test = shift;
    
    # Call parent startup
    $test->SUPER::test_startup();
    
    # Clear any existing singleton instance before each test class
    # This is important since SaveGame is a singleton
    require SoloGamer::SaveGame;
    SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
}

sub test_save_game_singleton : Test(3) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    # Test singleton behavior
    my $save1 = SoloGamer::SaveGame->instance();
    my $save2 = SoloGamer::SaveGame->instance();
    
    isa_ok($save1, 'SoloGamer::SaveGame', 'first instance is SaveGame');
    isa_ok($save2, 'SoloGamer::SaveGame', 'second instance is SaveGame');
    is($save1, $save2, 'singleton returns same instance');
}

sub test_save_game_attributes : Test(3) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $temp_file = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json',
        UNLINK => 0
    )->filename;
    
    my $save = SoloGamer::SaveGame->instance(save_file => $temp_file);
    
    # Test basic attributes
    isa_ok($save->save, 'HASH', 'save is hash reference');
    is($save->save_file, $temp_file, 'save_file set correctly');
    
    # Test Logger role
    can_ok($save, 'devel', 'SaveGame has Logger role methods');
}

sub test_save_game_save_attribute_default : Test(2) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $save = SoloGamer::SaveGame->instance();
    
    # Test save attribute defaults
    isa_ok($save->save, 'HASH', 'save defaults to hash reference');
    is(scalar keys %{$save->save}, 0, 'save defaults to empty hash');
}

sub test_save_game_mission_attribute : Test(2) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $save = SoloGamer::SaveGame->instance();
    
    # Test mission attribute (PositiveInt constraint)
    $save->mission(1);
    is($save->mission, 1, 'mission can be set to positive integer');
    
    # Test type constraint
    like(
        dies { $save->mission(0) },
        qr/type constraint/i,
        'mission rejects zero (must be positive)'
    );
}

sub test_load_save_nonexistent_file : Test(2) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $nonexistent_file = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json'
    )->filename;
    
    # Delete the file to make it nonexistent
    unlink $nonexistent_file;
    
    my $save = SoloGamer::SaveGame->instance(save_file => $nonexistent_file);
    
    # Test load_save with nonexistent file (should not die)
    lives_ok { $save->load_save() } 'load_save survives nonexistent file';
    
    # Test that mission defaults to 1 when no save file exists
    is($save->mission, 1, 'mission defaults to 1 for new save');
}

sub test_load_save_existing_file : Test(3) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    require Mojo::JSON;
    
    # Create a test save file
    my $save_data = {
        mission => [
            {number => 1, completed => 1},
            {number => 2, completed => 1}
        ]
    };
    
    my $temp_file = $test->create_temp_json_file($save_data);
    
    my $save = SoloGamer::SaveGame->instance(save_file => $temp_file);
    
    # Test loading existing save
    lives_ok { $save->load_save() } 'load_save loads existing file';
    
    # Test that save data is loaded
    isa_ok($save->save, 'HASH', 'save data loaded as hash');
    
    # Test mission calculation (last mission + 1)
    is($save->mission, 3, 'mission calculated correctly from existing save');
}

sub test_load_save_empty_file : Test(2) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    # Create empty JSON file
    my $temp_file = $test->create_temp_json_file({});
    
    my $save = SoloGamer::SaveGame->instance(save_file => $temp_file);
    
    # Test loading empty save file
    lives_ok { $save->load_save() } 'load_save handles empty save file';
    
    # Test that mission defaults to 1 for empty save
    is($save->mission, 1, 'mission defaults to 1 for empty save');
}

sub test_load_save_invalid_json : Test(1) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    # Create file with invalid JSON
    my $fh = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json',
        UNLINK => 0
    );
    print $fh "{ invalid json }";
    close $fh;
    
    my $save = SoloGamer::SaveGame->instance(save_file => $fh->filename);
    
    # Test that invalid JSON causes failure
    like(
        dies { $save->load_save() },
        qr/./,
        'load_save dies on invalid JSON'
    );
}

sub test_save_attribute_read_write : Test(3) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $save = SoloGamer::SaveGame->instance();
    
    # Test initial state
    isa_ok($save->save, 'HASH', 'save is initially hash');
    
    # Test setting save data
    my $new_save_data = {
        mission => [{number => 1}],
        player => {name => 'Test Player'}
    };
    
    $save->save($new_save_data);
    is($save->save, $new_save_data, 'save can be set');
    
    # Test that data persists
    is($save->save->{player}->{name}, 'Test Player', 'save data persists correctly');
}

sub test_save_game_inheritance : Test(2) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $save = SoloGamer::SaveGame->instance();
    
    # Test Logger role
    can_ok($save, 'verbose', 'SaveGame has Logger role methods');
    can_ok($save, 'devel', 'SaveGame has devel method from Logger');
}

sub test_save_game_type_library_usage : Test(1) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    my $save = SoloGamer::SaveGame->instance();
    
    # Test that PositiveInt type constraint is enforced
    like(
        dies { $save->mission(-1) },
        qr/type constraint/i,
        'mission enforces PositiveInt constraint'
    );
}

sub test_save_game_mission_calculation : Test(4) {
    my $test = shift;
    
    require SoloGamer::SaveGame;
    
    # Test various mission scenarios
    my @test_cases = (
        {
            desc => 'single mission',
            missions => [{number => 1, completed => 1}],
            expected => 2
        },
        {
            desc => 'multiple missions',
            missions => [
                {number => 1, completed => 1},
                {number => 2, completed => 1},
                {number => 3, completed => 1}
            ],
            expected => 4
        },
        {
            desc => 'empty mission array',
            missions => [],
            expected => 1
        },
        {
            desc => 'no mission key',
            missions => undef,
            expected => 1
        }
    );
    
    foreach my $case (@test_cases) {
        my $save_data = $case->{missions} ? {mission => $case->{missions}} : {};
        my $temp_file = $test->create_temp_json_file($save_data);
        
        # Clear singleton and create new instance
        SoloGamer::SaveGame->_clear_instance() if SoloGamer::SaveGame->can('_clear_instance');
        my $save = SoloGamer::SaveGame->instance(save_file => $temp_file);
        
        $save->load_save();
        is($save->mission, $case->{expected}, "mission calculation correct for $case->{desc}");
    }
}

1;