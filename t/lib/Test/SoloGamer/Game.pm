package Test::SoloGamer::Game;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions
use File::Temp;
use Test::MockObject;

use lib '/perl';

extends 'Test::SoloGamer::Base';

sub test_game_creation : Test(4) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    isa_ok($game, 'SoloGamer::Game', 'game is Game object');
    isa_ok($game, 'SoloGamer::Base', 'Game extends Base');
    
    # Test required attributes
    is($game->name, 'test-game', 'game name set correctly');
    isa_ok($game->tables, 'HASH', 'tables is hash reference');
}

sub test_game_attributes : Test(5) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $temp_save_file = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json'
    )->filename;
    
    my $game = $test->create_test_game({
        save_file => $temp_save_file,
        automated => 1,
        use_color => 0
    });
    
    # Test optional attributes
    is($game->save_file, $temp_save_file, 'save_file set correctly');
    ok($game->automated, 'automated set to true');
    ok(!$game->use_color, 'use_color set to false');
    
    # Test defaults
    my $default_game = $test->create_test_game();
    ok($default_game->use_color, 'use_color defaults to true');
    ok(!$default_game->automated, 'automated defaults to false');
}

sub test_game_inheritance : Test(4) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test inheritance chain
    isa_ok($game, 'SoloGamer::Base', 'Game extends Base');
    
    # Test roles
    can_ok($game, 'buffer', 'Game has BufferedOutput role methods');
    can_ok($game, 'print_output', 'Game has print_output from BufferedOutput');
    can_ok($game, 'devel', 'Game has Logger methods through Base');
}

sub test_game_lazy_attributes : Test(4) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test lazy attributes exist
    can_ok($game, 'save', 'game has save method');
    can_ok($game, 'source_data', 'game has source_data method');
    can_ok($game, 'source', 'game has source method');
    can_ok($game, 'tables', 'game has tables method');
}

sub test_game_zone_attribute : Test(2) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test zone attribute (read-write)
    can_ok($game, 'zone', 'game has zone method');
    
    # Test zone is read-write
    $game->zone('target-zone');
    is($game->zone, 'target-zone', 'zone can be set');
}

sub test_game_required_name : Test(1) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    # Test that name is required
    like(
        dies { SoloGamer::Game->new() },
        qr/required/i,
        'name is required for Game creation'
    );
}

sub test_game_with_save_file : Test(2) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $temp_save_file = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json'
    )->filename;
    
    my $game = $test->create_test_game({
        save_file => $temp_save_file
    });
    
    is($game->save_file, $temp_save_file, 'save_file attribute set');
    
    # Test that save is built correctly
    isa_ok($game->save, ['SoloGamer::SaveGame', 'HASH'], 'save is built');
}

sub test_game_automated_modes : Test(4) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    # Test automated = true
    my $automated_game = $test->create_test_game({automated => 1});
    ok($automated_game->automated, 'automated mode enabled');
    
    # Test automated = false
    my $manual_game = $test->create_test_game({automated => 0});
    ok(!$manual_game->automated, 'automated mode disabled');
    
    # Test default automated
    my $default_game = $test->create_test_game();
    ok(!$default_game->automated, 'automated defaults to false');
    
    # Test automated type constraint (should be Bool)
    my $game_with_automated = $test->create_test_game({automated => 'true'});
    # This should work since Perl is flexible with truthy values
    ok($game_with_automated->automated, 'automated accepts truthy string');
}

sub test_game_use_color_attribute : Test(3) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    # Test use_color = true
    my $color_game = $test->create_test_game({use_color => 1});
    ok($color_game->use_color, 'use_color enabled');
    
    # Test use_color = false
    my $no_color_game = $test->create_test_game({use_color => 0});
    ok(!$no_color_game->use_color, 'use_color disabled');
    
    # Test default use_color
    my $default_game = $test->create_test_game();
    ok($default_game->use_color, 'use_color defaults to true');
}

sub test_game_buffered_output_functionality : Test(3) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test BufferedOutput role functionality
    $game->buffer('test line 1');
    $game->buffer('test line 2');
    
    is(scalar @{$game->buffered_output}, 2, 'buffer stores lines correctly');
    
    # Test formatted buffer methods
    $game->buffer_success('success message');
    is(scalar @{$game->buffered_output}, 3, 'buffer_success adds to buffer');
    
    # Test buffer clearing
    $game->flush();
    is(scalar @{$game->buffered_output}, 0, 'flush clears buffer');
}

sub test_game_tables_attribute : Test(2) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test that tables is a hash
    isa_ok($game->tables, 'HASH', 'tables is hash reference');
    
    # Test that tables can contain data (this would be built by _build_load_data_tables)
    # For testing purposes, we'll just verify the structure
    ok(defined $game->tables, 'tables attribute is defined');
}

sub test_game_complex_creation : Test(5) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    # Create game with all optional parameters
    my $temp_save_file = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json'
    )->filename;
    
    my $game = $test->create_test_game({
        save_file => $temp_save_file,
        automated => 1,
        use_color => 0
    });
    
    # Test all attributes are set correctly
    isa_ok($game, 'SoloGamer::Game', 'complex game created');
    is($game->name, 'test-game', 'name set correctly');
    is($game->save_file, $temp_save_file, 'save_file set correctly');
    ok($game->automated, 'automated set correctly');
    ok(!$game->use_color, 'use_color set correctly');
}

sub test_game_builder_methods : Test(4) {
    my $test = shift;
    
    require SoloGamer::Game;
    
    my $game = $test->create_test_game();
    
    # Test that builder methods are called for lazy attributes
    # We can't easily test the actual building without mocking the file system
    # But we can verify the attributes exist and are the expected types
    
    can_ok($game, '_build_save', 'has _build_save method');
    can_ok($game, '_build_source_data', 'has _build_source_data method');
    can_ok($game, '_build_source', 'has _build_source method');
    can_ok($game, '_build_load_data_tables', 'has _build_load_data_tables method');
}

# Helper method to create a test game
sub create_test_game {
    my ($test, $additional_attributes) = @_;
    
    require SoloGamer::Game;
    
    my %args = (
        name => 'test-game',
        %{$additional_attributes || {}}
    );
    
    # Mock the game creation since it requires file system access
    # In a real test, you'd want to create actual test data files
    
    # For now, create a minimal working Game object
    return SoloGamer::Game->new(%args);
}

1;