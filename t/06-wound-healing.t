#!/usr/bin/env perl

use v5.42;
use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/../perl";

use SoloGamer::QotS::Crew;
use SoloGamer::QotS::CrewMember;

# Test for wound healing functionality
# Light wounds heal between missions
# Serious wounds require survival rolls after landing

# Test 1: Light wounds heal between missions
subtest 'Light wounds heal between missions' => sub {
    plan tests => 5;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Create crew members with light wounds
    my $wounded1 = SoloGamer::QotS::CrewMember->new(
        name     => 'Test Wounded 1',
        position => 'pilot',
        missions => 5,
    );
    $wounded1->apply_wound('light', 'arm');

    my $wounded2 = SoloGamer::QotS::CrewMember->new(
        name     => 'Test Wounded 2',
        position => 'navigator',
        missions => 3,
    );
    $wounded2->apply_wound('light', 'leg');

    # Add healthy crew member
    my $healthy = SoloGamer::QotS::CrewMember->new(
        name     => 'Test Healthy',
        position => 'bombardier',
        missions => 10,
    );

    $crew->crew_members->{pilot} = $wounded1;
    $crew->crew_members->{navigator} = $wounded2;
    $crew->crew_members->{bombardier} = $healthy;

    # Verify initial state
    is($wounded1->wound_status, 'light', 'Pilot has light wound');
    is($wounded2->wound_status, 'light', 'Navigator has light wound');
    is($healthy->wound_status, 'none', 'Bombardier has no wounds');

    # Heal light wounds
    my $healed = $crew->heal_light_wounds();

    is($healed, 2, 'Two crew members healed');
    is($wounded1->wound_status, 'none', 'Pilot light wound healed');
};

# Test 2: Serious wounds do not auto-heal
subtest 'Serious wounds do not auto-heal' => sub {
    plan tests => 3;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    my $seriously_wounded = SoloGamer::QotS::CrewMember->new(
        name     => 'Test Serious',
        position => 'tail_gunner',
        missions => 5,
    );
    $seriously_wounded->apply_wound('serious', 'chest');

    $crew->crew_members->{tail_gunner} = $seriously_wounded;

    is($seriously_wounded->wound_status, 'serious', 'Has serious wound');

    my $healed = $crew->heal_light_wounds();

    is($healed, 0, 'No wounds healed');
    is($seriously_wounded->wound_status, 'serious', 'Serious wound remains');
};

# Test 3: KIA crew members are not healed
subtest 'KIA crew members are not healed' => sub {
    plan tests => 3;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    my $kia = SoloGamer::QotS::CrewMember->new(
        name     => 'Test KIA',
        position => 'ball_gunner',
        missions => 5,
    );
    $kia->apply_wound('light', 'arm');
    $kia->set_disposition('KIA');

    $crew->crew_members->{ball_gunner} = $kia;

    is($kia->wound_status, 'light', 'KIA has light wound');

    my $healed = $crew->heal_light_wounds();

    is($healed, 0, 'No wounds healed for KIA');
    is($kia->wound_status, 'light', 'KIA wound status unchanged');
};

# Test 4: Multiple light wounds heal
subtest 'Multiple light wounds heal at once' => sub {
    plan tests => 7;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Create 4 wounded crew
    for my $pos (qw(pilot navigator bombardier copilot)) {
        my $member = SoloGamer::QotS::CrewMember->new(
            name     => "Test $pos",
            position => $pos,
        );
        $member->apply_wound('light', 'body');
        $crew->crew_members->{$pos} = $member;
    }

    # Verify all wounded
    for my $pos (qw(pilot navigator bombardier copilot)) {
        is($crew->crew_members->{$pos}->wound_status, 'light', "$pos has light wound");
    }

    # Heal all
    my $healed = $crew->heal_light_wounds();

    is($healed, 4, 'Four crew members healed');
    is($crew->crew_members->{pilot}->wound_status, 'none', 'Pilot healed');
    is($crew->crew_members->{navigator}->wound_status, 'none', 'Navigator healed');
};

# Test 5: IH crew members are not healed
subtest 'IH crew members are not healed' => sub {
    plan tests => 3;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    my $ih = SoloGamer::QotS::CrewMember->new(
        name     => 'Test IH',
        position => 'engineer',
        missions => 5,
    );
    $ih->apply_wound('light', 'arm');
    $ih->set_disposition('IH');

    $crew->crew_members->{engineer} = $ih;

    is($ih->wound_status, 'light', 'IH has light wound');

    my $healed = $crew->heal_light_wounds();

    is($healed, 0, 'No wounds healed for IH');
    is($ih->wound_status, 'light', 'IH wound status unchanged');
};

# Test 6: Crew with no wounds
subtest 'Crew with no wounds' => sub {
    plan tests => 2;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    my $healthy = SoloGamer::QotS::CrewMember->new(
        name     => 'Test Healthy',
        position => 'pilot',
    );

    $crew->crew_members->{pilot} = $healthy;

    is($healthy->wound_status, 'none', 'Crew member has no wounds');

    my $healed = $crew->heal_light_wounds();

    is($healed, 0, 'No wounds to heal');
};

done_testing();
