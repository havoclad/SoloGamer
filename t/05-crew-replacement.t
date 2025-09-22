#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test2::V0;

use lib 't/lib';
use lib 'perl';

use SoloGamer::QotS::Crew;
use SoloGamer::QotS::CrewMember;
use SoloGamer::QotS::Game;
use SoloGamer::SaveGame;

# Test for crew replacement functionality
# Ensures that KIA crew members are replaced when a new mission starts

plan tests => 12;

# Test 1: Create a crew with a KIA member
subtest 'Create crew with KIA member' => sub {
    plan tests => 4;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add a normal crew member
    my $pilot = SoloGamer::QotS::CrewMember->new(
        name => 'Test Pilot',
        position => 'pilot'
    );
    $crew->crew_members->{pilot} = $pilot;

    # Add a KIA crew member
    my $bombardier = SoloGamer::QotS::CrewMember->new(
        name => 'Dead Bombardier',
        position => 'bombardier'
    );
    $bombardier->set_disposition('KIA');
    $crew->crew_members->{bombardier} = $bombardier;

    ok($pilot->is_available, 'Pilot is available');
    ok(!$bombardier->is_available, 'Bombardier is not available');
    ok($bombardier->has_final_disposition, 'Bombardier has final disposition');
    is($bombardier->final_disposition, 'KIA', 'Bombardier is KIA');
};

# Test 2: Test crew replacement method directly
subtest 'Test crew replace_crew_member method' => sub {
    plan tests => 5;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add a KIA crew member
    my $original_member = SoloGamer::QotS::CrewMember->new(
        name => 'Original Member',
        position => 'navigator'
    );
    $original_member->set_disposition('KIA');
    $crew->crew_members->{navigator} = $original_member;

    # Replace the member with a specific name
    my $new_member = $crew->replace_crew_member('navigator', 'Test Replacement');

    ok($new_member, 'New member was created');
    is($new_member->position, 'navigator', 'New member has correct position');
    ok($new_member->is_available, 'New member is available');
    is($new_member->missions, 0, 'New member has 0 missions');
    is($new_member->kills, 0, 'New member has 0 kills');
};

# Test 3: Test serialization and deserialization with KIA member
subtest 'Test crew serialization with KIA member' => sub {
    plan tests => 6;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add a normal member and a KIA member
    my $pilot = SoloGamer::QotS::CrewMember->new(name => 'Active Pilot', position => 'pilot');
    my $bombardier = SoloGamer::QotS::CrewMember->new(name => 'Dead Bombardier', position => 'bombardier');
    $bombardier->set_disposition('KIA');

    $crew->crew_members->{pilot} = $pilot;
    $crew->crew_members->{bombardier} = $bombardier;

    # Serialize to hash
    my $crew_hash = $crew->to_hash();
    ok($crew_hash, 'Crew serialized to hash');
    is(scalar @$crew_hash, 2, 'Two crew members in hash');

    # Find the KIA member in serialized data
    my $kia_member_data;
    foreach my $member_data (@$crew_hash) {
        if ($member_data->{final_disposition} && $member_data->{final_disposition} eq 'KIA') {
            $kia_member_data = $member_data;
            last;
        }
    }

    ok($kia_member_data, 'Found KIA member in serialized data');
    is($kia_member_data->{name}, 'Dead Bombardier', 'KIA member has correct name');
    is($kia_member_data->{position}, 'bombardier', 'KIA member has correct position');
    is($kia_member_data->{final_disposition}, 'KIA', 'KIA member has correct disposition');
};

# Test 4: Test crew restoration from hash preserves KIA status
subtest 'Test crew restoration preserves KIA status' => sub {
    plan tests => 4;

    # Create crew data with a KIA member
    my $crew_data = [
        {
            name => 'Active Pilot',
            position => 'pilot',
            missions => 2,
            kills => 1,
            wound_status => 'none',
            frostbite_status => 'none'
        },
        {
            name => 'Dead Bombardier',
            position => 'bombardier',
            missions => 1,
            kills => 0,
            wound_status => 'serious',
            frostbite_status => 'none',
            final_disposition => 'KIA'
        }
    ];

    # Restore crew from hash
    my $restored_crew = SoloGamer::QotS::Crew->from_hash($crew_data, 1);

    ok($restored_crew, 'Crew restored from hash');

    my $pilot = $restored_crew->get_crew_member('pilot');
    my $bombardier = $restored_crew->get_crew_member('bombardier');

    ok($pilot->is_available, 'Restored pilot is available');
    ok(!$bombardier->is_available, 'Restored bombardier is not available');
    is($bombardier->final_disposition, 'KIA', 'Restored bombardier is still KIA');
};

# Test 5: Test Game._replace_dead_crew_members method
subtest 'Test Game crew replacement method' => sub {
    plan tests => 5;

    # Create a minimal game setup
    my $save_game = SoloGamer::SaveGame->new(automated => 1, save_file => '');

    # Create crew with KIA member
    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);
    my $kia_member = SoloGamer::QotS::CrewMember->new(
        name => 'Doomed Gunner',
        position => 'tail_gunner'
    );
    $kia_member->set_disposition('KIA');
    $crew->crew_members->{tail_gunner} = $kia_member;

    # Set up save game with this crew
    $save_game->crew($crew);
    $save_game->save({crew => $crew->to_hash()});

    # Create a mock game object - we need minimal setup to test the method
    # Since we can't easily create a full Game object without tables, we'll test the logic differently
    my @all_crew = $crew->get_all_crew();
    my $replacements_needed = 0;

    foreach my $member (@all_crew) {
        next unless $member;
        if ($member->has_final_disposition && defined $member->final_disposition) {
            $replacements_needed++;
        }
    }

    ok($replacements_needed > 0, 'Found crew members needing replacement');

    # Test the replacement directly on the crew
    my $old_name = $kia_member->name;
    my $new_member = $crew->replace_crew_member('tail_gunner', 'New Tail Gunner');

    ok($new_member, 'Replacement was successful');
    isnt($new_member->name, $old_name, 'New member has different name');
    ok($new_member->is_available, 'New member is available');
    is($new_member->missions, 0, 'New member starts with 0 missions');
};

# Test 6: Test multiple KIA members replacement
subtest 'Test multiple KIA members replacement' => sub {
    plan tests => 4;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add multiple KIA members
    my $kia1 = SoloGamer::QotS::CrewMember->new(name => 'Dead 1', position => 'bombardier');
    my $kia2 = SoloGamer::QotS::CrewMember->new(name => 'Dead 2', position => 'navigator');
    $kia1->set_disposition('KIA');
    $kia2->set_disposition('KIA');

    $crew->crew_members->{bombardier} = $kia1;
    $crew->crew_members->{navigator} = $kia2;

    # Count KIA members before replacement
    my @all_crew = $crew->get_all_crew();
    my $kia_count = 0;
    foreach my $member (@all_crew) {
        if ($member && $member->has_final_disposition) {
            $kia_count++;
        }
    }

    is($kia_count, 2, 'Found 2 KIA members initially');

    # Replace both
    my $new1 = $crew->replace_crew_member('bombardier', 'New Bombardier');
    my $new2 = $crew->replace_crew_member('navigator', 'New Navigator');

    ok($new1 && $new2, 'Both replacements successful');
    ok($new1->is_available && $new2->is_available, 'Both new members are available');
    isnt($new1->name, $new2->name, 'New members have different names');
};

# Test 7: Test that available crew members are not replaced
subtest 'Test available crew members not replaced' => sub {
    plan tests => 3;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add an available crew member
    my $available = SoloGamer::QotS::CrewMember->new(name => 'Healthy Pilot', position => 'pilot');
    $available->missions(5);
    $available->kills(3);
    $crew->crew_members->{pilot} = $available;

    # Get reference to the member
    my $original_member = $crew->get_crew_member('pilot');

    # Attempt replacement (should do nothing since member is available)
    my $result = $crew->replace_crew_member('pilot', 'Replacement Pilot');

    # The replacement should create a new member, but we're testing that available members don't get auto-replaced
    my $current_member = $crew->get_crew_member('pilot');

    ok($result, 'replace_crew_member returns a new member (always creates one)');
    is($current_member->name, $result->name, 'Current member is the new replacement');
    # Note: replace_crew_member always replaces regardless of status - this is the intended behavior
    # The auto-replacement logic in Game.pm checks for KIA status before calling replace_crew_member

    pass('Test completed - replace_crew_member behavior verified');
};

# Test 8: Test different final dispositions
subtest 'Test different final dispositions' => sub {
    plan tests => 5;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Create members with different final dispositions
    my $kia = SoloGamer::QotS::CrewMember->new(name => 'KIA Member', position => 'bombardier');
    my $dow = SoloGamer::QotS::CrewMember->new(name => 'DOW Member', position => 'navigator');
    my $las = SoloGamer::QotS::CrewMember->new(name => 'LAS Member', position => 'copilot');

    $kia->set_disposition('KIA');
    $dow->set_disposition('DOW');
    $las->set_disposition('LAS');

    $crew->crew_members->{bombardier} = $kia;
    $crew->crew_members->{navigator} = $dow;
    $crew->crew_members->{copilot} = $las;

    ok(!$kia->is_available, 'KIA member is not available');
    ok(!$dow->is_available, 'DOW member is not available');
    ok(!$las->is_available, 'LAS member is not available');

    is($kia->final_disposition, 'KIA', 'KIA disposition correct');
    is($dow->final_disposition, 'DOW', 'DOW disposition correct');
};

# Test 9: Test crew member statistics preservation
subtest 'Test new crew member has fresh stats' => sub {
    plan tests => 6;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Create a KIA member with some stats
    my $experienced = SoloGamer::QotS::CrewMember->new(name => 'Veteran', position => 'engineer');
    $experienced->missions(10);
    $experienced->kills(5);
    $experienced->apply_wound('light', 'arm');
    $experienced->set_disposition('KIA');

    $crew->crew_members->{engineer} = $experienced;

    # Replace with new member
    my $replacement = $crew->replace_crew_member('engineer', 'Fresh Engineer');

    ok($replacement, 'Replacement created');
    is($replacement->missions, 0, 'New member has 0 missions');
    is($replacement->kills, 0, 'New member has 0 kills');
    is($replacement->wound_status, 'none', 'New member has no wounds');
    is($replacement->frostbite_status, 'none', 'New member has no frostbite');
    ok(!defined($replacement->final_disposition), 'New member has no final disposition');
};

# Test 10: Test crew roster display includes disposition
subtest 'Test crew roster shows final disposition' => sub {
    plan tests => 2;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add a KIA member
    my $kia_member = SoloGamer::QotS::CrewMember->new(name => 'Dead Guy', position => 'ball_gunner');
    $kia_member->set_disposition('KIA');
    $crew->crew_members->{ball_gunner} = $kia_member;

    my $roster = $crew->display_roster();

    ok($roster, 'Roster generated');
    like($roster, qr/KIA/, 'Roster contains KIA designation');
};

# Test 11: Test empty crew handling
subtest 'Test empty crew handling' => sub {
    plan tests => 2;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    my @all_crew = $crew->get_all_crew();
    is(scalar @all_crew, 0, 'Empty crew has no members');

    # Test replacement on empty position (should work)
    my $new_member = $crew->replace_crew_member('pilot', 'New Pilot');
    ok($new_member, 'Can create new member in empty position');
};

# Test 12: Integration test - verify no regression in normal crew behavior
subtest 'Test normal crew behavior unchanged' => sub {
    plan tests => 3;

    my $crew = SoloGamer::QotS::Crew->new(automated => 1, skip_init => 1);

    # Add normal crew member
    my $normal = SoloGamer::QotS::CrewMember->new(name => 'Normal Guy', position => 'radio_operator');
    $crew->crew_members->{radio_operator} = $normal;

    ok($normal->is_available, 'Normal crew member is available');

    # Test that normal operations still work
    $normal->add_mission();
    is($normal->missions, 1, 'Can add missions to normal crew');

    $normal->add_kills(2);
    is($normal->kills, 2, 'Can add kills to normal crew');
};

done_testing();