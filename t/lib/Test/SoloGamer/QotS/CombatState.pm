package Test::SoloGamer::QotS::CombatState;

use v5.42;

use Test::Class::Moose;
use Test::Exception;

use SoloGamer::QotS::CombatState;

sub test_constructor {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  isa_ok($state, 'SoloGamer::QotS::CombatState', 'Constructor creates correct object');
  
  ok(!defined $state->current_wave, 'Current wave starts undefined');
  isa_ok($state->active_fighters, 'ARRAY', 'Active fighters is array');
  is(scalar @{$state->active_fighters}, 0, 'Active fighters starts empty');
  
  isa_ok($state->defensive_fire_queue, 'ARRAY', 'Defensive fire queue is array');
  is(scalar @{$state->defensive_fire_queue}, 0, 'Defensive fire queue starts empty');
  
  isa_ok($state->successive_attacks, 'HASH', 'Successive attacks is hash');
  is(scalar keys %{$state->successive_attacks}, 0, 'Successive attacks starts empty');
  
  isa_ok($state->ace_tracker, 'HASH', 'Ace tracker is hash');
  is(scalar keys %{$state->ace_tracker}, 0, 'Ace tracker starts empty');
  
  isa_ok($state->fighter_damage, 'HASH', 'Fighter damage is hash');
  is(scalar keys %{$state->fighter_damage}, 0, 'Fighter damage starts empty');
  
  is($state->wave_number, 0, 'Wave number starts at 0');
  is($state->zone, '', 'Zone starts empty');
  is($state->fighter_cover, 'none', 'Fighter cover defaults to none');
  is($state->formation_position, 'middle', 'Formation position defaults to middle');
}

sub test_wave_management {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  
  my $wave_data = {
    zone => '5o',
    fighters => [
      { type => 'Me109', position => '12 High' },
      { type => 'FW190', position => '3 Level' },
    ],
  };
  
  my $wave_num = $state->start_new_wave($wave_data);
  is($wave_num, 1, 'First wave is number 1');
  is($state->wave_number, 1, 'Wave number updated');
  is_deeply($state->current_wave, $wave_data, 'Wave data stored');
  
  ok($state->wave_in_progress(), 'Wave not in progress until fighters added');
  
  $state->start_new_wave({ zone => '6o' });
  is($state->wave_number, 2, 'Wave number incremented');
  is(scalar @{$state->active_fighters}, 0, 'Active fighters cleared on new wave');
  is(scalar keys %{$state->fighter_damage}, 0, 'Fighter damage cleared on new wave');
  
  dies_ok { $state->start_new_wave() } 'start_new_wave requires wave data';
}

sub test_fighter_tracking {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $fighter1_id = $state->add_fighter({
    type => 'Me109',
    position => '12 High',
  });
  
  like($fighter1_id, qr/^W1_Me_12_High_1$/, 'Fighter ID generated correctly');
  
  my $fighter2_id = $state->add_fighter({
    type => 'Me109',
    position => '12 High',
  });
  
  like($fighter2_id, qr/^W1_Me_12_High_2$/, 'Second fighter at same position gets unique ID');
  
  is(scalar @{$state->active_fighters}, 2, 'Two fighters added');
  
  my $fighter = $state->get_fighter($fighter1_id);
  isa_ok($fighter, 'HASH', 'get_fighter returns hash');
  is($fighter->{type}, 'Me109', 'Fighter type correct');
  is($fighter->{position}, '12 High', 'Fighter position correct');
  is($fighter->{status}, 'attacking', 'Fighter status defaults to attacking');
  is($fighter->{pilot}, 'regular', 'Fighter pilot defaults to regular');
  is($fighter->{attacks_made}, 0, 'Attacks made starts at 0');
  
  my $fighter3_id = $state->add_fighter({
    type => 'FW190',
    position => '1:30 Level',
    status => 'approaching',
    pilot => 'ace',
  });
  
  my $fighter3 = $state->get_fighter($fighter3_id);
  is($fighter3->{status}, 'approaching', 'Custom status respected');
  is($fighter3->{pilot}, 'ace', 'Custom pilot type respected');
  
  my $invalid = $state->get_fighter('invalid_id');
  ok(!defined $invalid, 'get_fighter returns undef for invalid ID');
  
  dies_ok { $state->add_fighter() } 'add_fighter requires data';
  dies_ok { $state->add_fighter({}) } 'add_fighter requires type';
  dies_ok { $state->add_fighter({type => 'Me109'}) } 'add_fighter requires position';
}

sub test_successive_attacks {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $fighter_id = $state->add_fighter({
    type => 'Me109',
    position => '12 High',
  });
  
  ok($state->can_make_successive_attack($fighter_id), 'Fighter can make successive attack initially');
  
  my $attack_num = $state->record_successive_attack($fighter_id);
  is($attack_num, 1, 'First attack recorded');
  is($state->successive_attacks->{$fighter_id}, 1, 'Successive attack tracked');
  
  my $fighter = $state->get_fighter($fighter_id);
  is($fighter->{attacks_made}, 1, 'Fighter attacks_made updated');
  
  ok($state->can_make_successive_attack($fighter_id), 'Can make second successive attack');
  
  $state->record_successive_attack($fighter_id);
  $state->record_successive_attack($fighter_id);
  
  is($fighter->{attacks_made}, 3, 'Fighter made 3 attacks');
  ok(!$state->can_make_successive_attack($fighter_id), 'Cannot make 4th attack');
  
  my $result = $state->record_successive_attack($fighter_id);
  is($result, 0, 'record_successive_attack returns 0 when max attacks reached');
  
  $state->update_fighter_status($fighter_id, 'driven_off');
  ok(!$state->can_make_successive_attack($fighter_id), 'Driven off fighter cannot attack');
  
  ok(!$state->can_make_successive_attack('invalid_id'), 'Invalid fighter cannot attack');
}

sub test_defensive_fire_queue {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $f1 = $state->add_fighter({ type => 'Me109', position => '6 High' });
  my $f2 = $state->add_fighter({ type => 'FW190', position => '12 Level' });
  my $f3 = $state->add_fighter({ type => 'Me110', position => '3 Low' });
  my $f4 = $state->add_fighter({ type => 'Me109', position => 'Vertical Dive' });
  
  $state->add_to_defensive_fire_queue($f1);
  $state->add_to_defensive_fire_queue($f2);
  $state->add_to_defensive_fire_queue($f3);
  $state->add_to_defensive_fire_queue($f4);
  
  is(scalar @{$state->defensive_fire_queue}, 4, 'Four fighters in queue');
  
  my $target = $state->get_next_defensive_target();
  is($target->{fighter_id}, $f2, '12 o\'clock has highest priority');
  
  $target = $state->get_next_defensive_target();
  is($target->{fighter_id}, $f4, 'Vertical Dive has second priority');
  
  $target = $state->get_next_defensive_target();
  is($target->{fighter_id}, $f3, 'Me110 gets priority boost');
  
  $target = $state->get_next_defensive_target();
  is($target->{fighter_id}, $f1, '6 o\'clock has lowest priority');
  
  $target = $state->get_next_defensive_target();
  ok(!defined $target, 'Queue empty returns undef');
  
  $state->add_to_defensive_fire_queue($f1, 1);
  my $queue = $state->defensive_fire_queue;
  is($queue->[0]->{priority}, 1, 'Custom priority respected');
  
  ok(!$state->add_to_defensive_fire_queue('invalid_id'), 'Invalid fighter not added to queue');
}

sub test_fighter_damage_states {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $fighter_id = $state->add_fighter({
    type => 'Me109',
    position => '12 High',
  });
  
  ok($state->damage_fighter($fighter_id, 'FCA'), 'damage_fighter returns true');
  
  my $damage = $state->fighter_damage->{$fighter_id};
  is($damage->{FCA_hits}, 1, 'FCA hit recorded');
  is($damage->{FBOA_hits}, 0, 'FBOA hits still 0');
  is($damage->{status}, 'undamaged', 'Status still undamaged after 1 FCA');
  
  my $fighter = $state->get_fighter($fighter_id);
  is($fighter->{status}, 'attacking', 'Fighter still attacking after 1 FCA');
  
  $state->damage_fighter($fighter_id, 'FCA', 'nose');
  is($damage->{FCA_hits}, 2, 'Second FCA hit recorded');
  is($damage->{status}, 'destroyed', 'Fighter destroyed after 2 FCA hits');
  is($fighter->{status}, 'destroyed', 'Fighter status updated to destroyed');
  
  is($state->ace_tracker->{nose}, 1, 'Kill credited to nose gunner');
  
  my $f2 = $state->add_fighter({ type => 'FW190', position => '3 Level' });
  $state->damage_fighter($f2, 'FBOA');
  
  my $f2_obj = $state->get_fighter($f2);
  is($f2_obj->{status}, 'breaking_off', 'FBOA causes fighter to break off');
  
  my $f3 = $state->add_fighter({ type => 'Me110', position => '9 High' });
  $state->damage_fighter($f3, 'destroyed', 'tail');
  
  my $f3_obj = $state->get_fighter($f3);
  is($f3_obj->{status}, 'destroyed', 'Direct destruction works');
  is($state->ace_tracker->{tail}, 1, 'Kill credited to tail gunner');
  
  ok(!$state->damage_fighter('invalid_id', 'FCA'), 'Invalid fighter returns false');
}

sub test_reset_per_zone {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  
  $state->start_new_wave({ zone => '5o' });
  my $f1 = $state->add_fighter({ type => 'Me109', position => '12 High' });
  $state->damage_fighter($f1, 'FCA');
  $state->record_successive_attack($f1);
  $state->add_to_defensive_fire_queue($f1);
  
  is($state->wave_number, 1, 'Wave number is 1');
  is(scalar @{$state->active_fighters}, 1, 'One active fighter');
  is(scalar keys %{$state->fighter_damage}, 1, 'Fighter damage tracked');
  is(scalar keys %{$state->successive_attacks}, 1, 'Successive attack tracked');
  is(scalar @{$state->defensive_fire_queue}, 1, 'Fighter in queue');
  
  ok($state->reset_for_zone('6o'), 'reset_for_zone returns true');
  
  is($state->zone, '6o', 'Zone updated');
  is($state->wave_number, 0, 'Wave number reset');
  ok(!defined $state->current_wave, 'Current wave cleared');
  is(scalar @{$state->active_fighters}, 0, 'Active fighters cleared');
  is(scalar keys %{$state->fighter_damage}, 0, 'Fighter damage cleared');
  is(scalar keys %{$state->successive_attacks}, 0, 'Successive attacks cleared');
  is(scalar @{$state->defensive_fire_queue}, 0, 'Defensive fire queue cleared');
}

sub test_ace_tracking {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $kills = $state->record_kill('nose');
  is($kills, 1, 'First kill recorded');
  is($state->ace_tracker->{nose}, 1, 'Ace tracker updated');
  
  $state->record_kill('nose');
  $state->record_kill('nose');
  $state->record_kill('nose');
  
  is($state->ace_tracker->{nose}, 4, 'Four kills tracked');
  
  $kills = $state->record_kill('nose');
  is($kills, 5, 'Fifth kill makes ace');
  
  $state->record_kill('tail');
  $state->record_kill('tail');
  
  my $summary = $state->get_kill_summary();
  isa_ok($summary, 'HASH', 'get_kill_summary returns hash');
  
  is($summary->{nose}->{kills}, 5, 'Nose gunner has 5 kills');
  is($summary->{nose}->{ace}, 1, 'Nose gunner is ace');
  
  is($summary->{tail}->{kills}, 2, 'Tail gunner has 2 kills');
  is($summary->{tail}->{ace}, 0, 'Tail gunner not ace');
}

sub test_fighter_status_updates {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  my $f1 = $state->add_fighter({ type => 'Me109', position => '12 High' });
  my $f2 = $state->add_fighter({ type => 'FW190', position => '3 Level' });
  
  $state->add_to_defensive_fire_queue($f1);
  $state->add_to_defensive_fire_queue($f2);
  $state->record_successive_attack($f1);
  
  is(scalar @{$state->defensive_fire_queue}, 2, 'Two fighters in queue');
  ok(exists $state->successive_attacks->{$f1}, 'Fighter has successive attack');
  
  ok($state->update_fighter_status($f1, 'driven_off'), 'update_fighter_status returns true');
  
  my $fighter = $state->get_fighter($f1);
  is($fighter->{status}, 'driven_off', 'Fighter status updated');
  
  is(scalar @{$state->defensive_fire_queue}, 1, 'Driven off fighter removed from queue');
  ok(!exists $state->successive_attacks->{$f1}, 'Successive attack removed');
  
  $state->update_fighter_status($f2, 'destroyed');
  is(scalar @{$state->defensive_fire_queue}, 0, 'Destroyed fighter removed from queue');
  
  ok(!$state->update_fighter_status('invalid_id', 'destroyed'), 'Invalid fighter returns false');
}

sub test_active_and_destroyed_counts {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  $state->start_new_wave({ zone => '5o' });
  
  is($state->get_active_fighter_count(), 0, 'No active fighters initially');
  is($state->get_destroyed_fighter_count(), 0, 'No destroyed fighters initially');
  
  my $f1 = $state->add_fighter({ type => 'Me109', position => '12 High' });
  my $f2 = $state->add_fighter({ type => 'FW190', position => '3 Level' });
  my $f3 = $state->add_fighter({ type => 'Me110', position => '6 Low' });
  
  is($state->get_active_fighter_count(), 3, 'Three active fighters');
  
  $state->update_fighter_status($f1, 'destroyed');
  is($state->get_active_fighter_count(), 2, 'Two active fighters after one destroyed');
  is($state->get_destroyed_fighter_count(), 1, 'One destroyed fighter');
  
  $state->update_fighter_status($f2, 'driven_off');
  is($state->get_active_fighter_count(), 1, 'One active fighter');
  is($state->get_destroyed_fighter_count(), 1, 'Still one destroyed fighter');
  
  $state->update_fighter_status($f3, 'destroyed');
  is($state->get_active_fighter_count(), 0, 'No active fighters');
  is($state->get_destroyed_fighter_count(), 2, 'Two destroyed fighters');
}

sub test_wave_completion {
  my $test = shift;
  
  my $state = SoloGamer::QotS::CombatState->new();
  
  ok(!$state->complete_wave(), 'Cannot complete wave when none started');
  
  $state->start_new_wave({ zone => '5o' });
  ok(!$state->complete_wave(), 'Cannot complete wave with no fighters');
  
  my $f1 = $state->add_fighter({ type => 'Me109', position => '12 High' });
  
  ok(!$state->wave_in_progress(), 'Wave in progress with active fighter');
  ok(!$state->complete_wave(), 'Cannot complete wave with active fighters');
  
  $state->update_fighter_status($f1, 'destroyed');
  
  ok(!$state->wave_in_progress(), 'Wave not in progress when no active fighters');
  ok($state->complete_wave(), 'Can complete wave when no active fighters');
  
  ok(!defined $state->current_wave, 'Current wave cleared after completion');
  is($state->wave_number, 1, 'Wave number preserved after completion');
}

__PACKAGE__->meta->make_immutable;
1;