#!/usr/bin/env perl

use v5.42;
use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/../perl";

use SoloGamer::QotS::DamageResolver;
use SoloGamer::QotS::AircraftState;
use SoloGamer::QotS::Crew;

# Test basic damage resolver functionality
subtest 'DamageResolver basic functionality' => sub {
    my $aircraft = SoloGamer::QotS::AircraftState->new();

    # Create crew with predefined data to avoid file dependencies
    my $crew_data = [
        { name => 'Test Bombardier', position => 'bombardier' },
        { name => 'Test Navigator', position => 'navigator' },
        { name => 'Test Pilot', position => 'pilot' },
        { name => 'Test Copilot', position => 'copilot' },
        { name => 'Test Engineer', position => 'engineer' },
        { name => 'Test Radio', position => 'radio_operator' },
        { name => 'Test Ball', position => 'ball_gunner' },
        { name => 'Test Port', position => 'port_waist_gunner' },
        { name => 'Test Starboard', position => 'starboard_waist_gunner' },
        { name => 'Test Tail', position => 'tail_gunner' },
    ];
    my $crew = SoloGamer::QotS::Crew->from_hash($crew_data, 1);

    my $resolver = SoloGamer::QotS::DamageResolver->new(
        aircraft_state => $aircraft,
        crew          => $crew,
    );

    isa_ok($resolver, 'SoloGamer::QotS::DamageResolver');

    # Test gun damage
    my $gun_damage_result = {
        damage_effects => [
            {
                type => 'gun_damage',
                position => 'nose',
                damage_type => 'destroy'
            }
        ]
    };

    my @reports = $resolver->resolve_damage($gun_damage_result);
    ok(@reports > 0, "Gun damage generates report");
    like($reports[0], qr/nose gun destroyed/i, "Gun damage report is correct");

    # Verify gun was actually damaged
    is($aircraft->guns->{nose}->{status}, 'destroyed', "Nose gun was actually destroyed");
};

subtest 'Crew wound handling' => sub {
    my $aircraft = SoloGamer::QotS::AircraftState->new();

    # Create crew with predefined data
    my $crew_data = [
        { name => 'Test Bombardier', position => 'bombardier' },
        { name => 'Test Navigator', position => 'navigator' },
        { name => 'Test Pilot', position => 'pilot' },
        { name => 'Test Copilot', position => 'copilot' },
        { name => 'Test Engineer', position => 'engineer' },
        { name => 'Test Radio', position => 'radio_operator' },
        { name => 'Test Ball', position => 'ball_gunner' },
        { name => 'Test Port', position => 'port_waist_gunner' },
        { name => 'Test Starboard', position => 'starboard_waist_gunner' },
        { name => 'Test Tail', position => 'tail_gunner' },
    ];
    my $crew = SoloGamer::QotS::Crew->from_hash($crew_data, 1);

    my $resolver = SoloGamer::QotS::DamageResolver->new(
        aircraft_state => $aircraft,
        crew          => $crew,
    );

    # Test crew wound
    my $crew_damage_result = {
        damage_effects => [
            {
                type => 'crew_wound',
                position => 'bombardier',
                severity => 'light',
                location => 'arm'
            }
        ]
    };

    my @reports = $resolver->resolve_damage($crew_damage_result);
    ok(@reports > 0, "Crew wound generates report");
    like($reports[0], qr/bombardier.*lightly wounded.*arm/i, "Crew wound report is correct");

    # Verify crew member was actually wounded
    my $bombardier = $crew->get_crew_member('bombardier');
    ok($bombardier, "Bombardier exists");
    is($bombardier->wound_status, 'light', "Bombardier has light wound");
};

subtest 'Engine damage handling' => sub {
    my $aircraft = SoloGamer::QotS::AircraftState->new();

    # Create crew with predefined data
    my $crew_data = [
        { name => 'Test Bombardier', position => 'bombardier' },
        { name => 'Test Navigator', position => 'navigator' },
        { name => 'Test Pilot', position => 'pilot' },
        { name => 'Test Copilot', position => 'copilot' },
        { name => 'Test Engineer', position => 'engineer' },
        { name => 'Test Radio', position => 'radio_operator' },
        { name => 'Test Ball', position => 'ball_gunner' },
        { name => 'Test Port', position => 'port_waist_gunner' },
        { name => 'Test Starboard', position => 'starboard_waist_gunner' },
        { name => 'Test Tail', position => 'tail_gunner' },
    ];
    my $crew = SoloGamer::QotS::Crew->from_hash($crew_data, 1);

    my $resolver = SoloGamer::QotS::DamageResolver->new(
        aircraft_state => $aircraft,
        crew          => $crew,
    );

    # Test engine damage
    my $engine_damage_result = {
        damage_effects => [
            {
                type => 'engine_damage',
                engine => 1,
                damage_type => 'fire'
            }
        ]
    };

    my @reports = $resolver->resolve_damage($engine_damage_result);
    ok(@reports > 0, "Engine damage generates report");
    like($reports[0], qr/on fire/i, "Engine fire report is correct");

    # Verify engine was actually damaged
    is($aircraft->engines->{1}->{status}, 'on_fire', "Engine 1 is on fire");
};

subtest 'Legacy text parsing fallback' => sub {
    my $aircraft = SoloGamer::QotS::AircraftState->new();

    # Create crew with predefined data
    my $crew_data = [
        { name => 'Test Bombardier', position => 'bombardier' },
        { name => 'Test Navigator', position => 'navigator' },
        { name => 'Test Pilot', position => 'pilot' },
        { name => 'Test Copilot', position => 'copilot' },
        { name => 'Test Engineer', position => 'engineer' },
        { name => 'Test Radio', position => 'radio_operator' },
        { name => 'Test Ball', position => 'ball_gunner' },
        { name => 'Test Port', position => 'port_waist_gunner' },
        { name => 'Test Starboard', position => 'starboard_waist_gunner' },
        { name => 'Test Tail', position => 'tail_gunner' },
    ];
    my $crew = SoloGamer::QotS::Crew->from_hash($crew_data, 1);

    my $resolver = SoloGamer::QotS::DamageResolver->new(
        aircraft_state => $aircraft,
        crew          => $crew,
    );

    # Test legacy text parsing (no damage_effects)
    my $text_damage_result = {
        result => 'Navigator wounded'
    };

    my @reports = $resolver->resolve_damage($text_damage_result);
    ok(@reports > 0, "Text damage generates report");

    # Check if navigator was wounded
    my $navigator = $crew->get_crew_member('navigator');
    ok($navigator, "Navigator exists");
    # Navigator should be wounded from text parsing
    ok($navigator->wound_status ne 'none', "Navigator was wounded from text parsing");
};

done_testing;