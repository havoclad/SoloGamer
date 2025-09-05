#!/usr/bin/env perl
use v5.42;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../perl";

use SoloGamer::Formatter;
use SoloGamer::ColorScheme::Registry;
use SoloGamer::ColorScheme::MilitaryGreen;
use SoloGamer::ColorScheme::ClassicAviation;
use SoloGamer::ColorScheme::VintageWWII;
use SoloGamer::ColorScheme::TerminalClassic;

# Test individual color schemes
subtest 'Military Green scheme' => sub {
    my $scheme = SoloGamer::ColorScheme::MilitaryGreen->new();
    
    is($scheme->name, 'Military Green & Gold', 'correct name');
    is($scheme->get_color_for('Welcome to B-17'), 'bright_green', 'welcome color');
    is($scheme->get_color_for('MISSION 1'), 'yellow', 'mission color');
    is($scheme->get_color_for('OUTCOME'), 'bright_yellow', 'outcome color');
    is($scheme->get_color_for('PLAYTHROUGH OVER'), 'bright_magenta', 'gameover color');
    is($scheme->get_color_for('Random text'), 'bold cyan', 'default color');
};

subtest 'Classic Aviation scheme' => sub {
    my $scheme = SoloGamer::ColorScheme::ClassicAviation->new();
    
    is($scheme->name, 'Classic Aviation', 'correct name');
    is($scheme->get_color_for('Welcome to B-17'), 'bright_blue', 'welcome color');
    is($scheme->get_color_for('MISSION 1'), 'white', 'mission color');
    is($scheme->get_color_for('OUTCOME'), 'bright_cyan', 'outcome color');
    is($scheme->get_color_for('PLAYTHROUGH OVER'), 'bright_yellow', 'gameover color');
};

subtest 'Vintage WWII scheme' => sub {
    my $scheme = SoloGamer::ColorScheme::VintageWWII->new();
    
    is($scheme->name, 'Vintage WWII', 'correct name');
    is($scheme->get_color_for('Welcome to B-17'), 'bright_yellow', 'welcome color');
    is($scheme->get_color_for('MISSION 1'), 'bright_red', 'mission color');
    is($scheme->get_color_for('OUTCOME'), 'bright_green', 'outcome color');
    is($scheme->get_color_for('PLAYTHROUGH OVER'), 'bright_white', 'gameover color');
};

subtest 'Terminal Classic scheme' => sub {
    my $scheme = SoloGamer::ColorScheme::TerminalClassic->new();
    
    is($scheme->name, 'Terminal Classic', 'correct name');
    is($scheme->get_color_for('Welcome to B-17'), 'bright_magenta', 'welcome color');
    is($scheme->get_color_for('MISSION 1'), 'bright_cyan', 'mission color');
    is($scheme->get_color_for('OUTCOME'), 'bright_white', 'outcome color');
    is($scheme->get_color_for('PLAYTHROUGH OVER'), 'bright_red', 'gameover color');
};

subtest 'Registry' => sub {
    my $registry = SoloGamer::ColorScheme::Registry->new();
    
    # Test scheme loading
    ok($registry->schemes->{military_green}, 'military_green loaded');
    ok($registry->schemes->{classic_aviation}, 'classic_aviation loaded');
    ok($registry->schemes->{vintage_wwii}, 'vintage_wwii loaded');
    ok($registry->schemes->{terminal_classic}, 'terminal_classic loaded');
    
    # Test backwards compatibility with numeric IDs
    ok($registry->schemes->{1}, 'scheme 1 available (backwards compat)');
    ok($registry->schemes->{2}, 'scheme 2 available (backwards compat)');
    ok($registry->schemes->{3}, 'scheme 3 available (backwards compat)');
    ok($registry->schemes->{4}, 'scheme 4 available (backwards compat)');
    
    # Test scheme retrieval
    my $scheme = $registry->get_scheme('military');
    is($scheme->name, 'Military Green & Gold', 'get_scheme works with short name');
    
    $scheme = $registry->get_scheme('1');
    is($scheme->name, 'Military Green & Gold', 'get_scheme works with numeric ID');
    
    # Test default scheme
    $scheme = $registry->get_scheme();
    is($scheme->name, 'Terminal Classic', 'default scheme is Terminal Classic');
    
    # Test list_schemes
    my @schemes = $registry->list_schemes();
    is(scalar(@schemes), 4, 'four unique schemes listed');
};

subtest 'Formatter integration' => sub {
    my $formatter = SoloGamer::Formatter->new();
    
    # Test that formatter has color scheme attributes
    ok($formatter->color_registry, 'formatter has color registry');
    ok($formatter->color_scheme, 'formatter has default color scheme');
    
    # Test box_header with different schemes
    my $header = $formatter->box_header('MISSION 1', 40, '1');
    like($header, qr/MISSION 1/, 'box_header contains text');
    ok(length($header) > 0, 'box_header produces output');
};

subtest 'Environment variable support' => sub {
    local $ENV{COLOR_SCHEME} = 'military';
    my $registry = SoloGamer::ColorScheme::Registry->new();
    my $scheme = $registry->get_scheme();
    is($scheme->name, 'Military Green & Gold', 'COLOR_SCHEME env var works');
    
    # Clear COLOR_SCHEME so BANNER_COLOR_SCHEME can be tested
    delete local $ENV{COLOR_SCHEME};
    local $ENV{BANNER_COLOR_SCHEME} = '2';
    $registry = SoloGamer::ColorScheme::Registry->new();
    $scheme = $registry->get_scheme();
    is($scheme->name, 'Classic Aviation', 'BANNER_COLOR_SCHEME env var works (backwards compat)');
};

done_testing();