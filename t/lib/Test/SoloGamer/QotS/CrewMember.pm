package Test::SoloGamer::QotS::CrewMember;

use v5.42;

use Test::Class::Moose;
use Test::Exception;

use SoloGamer::QotS::CrewMember;

sub test_constructor {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  isa_ok($member, 'SoloGamer::QotS::CrewMember', 'Constructor creates correct object');
  is($member->name, 'John Smith', 'Name is set correctly');
  is($member->position, 'pilot', 'Position is set correctly');
  is($member->missions, 0, 'Default missions is 0');
  is($member->kills, 0, 'Default kills is 0');
  is($member->wound_status, 'none', 'Default wound status is none');
  ok(!$member->has_final_disposition, 'No final disposition by default');
}

sub test_is_available {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  ok($member->is_available, 'New crew member is available');
  
  $member->set_disposition('KIA');
  ok(!$member->is_available, 'Crew member with final disposition is not available');
}

sub test_add_mission {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  $member->add_mission();
  is($member->missions, 1, 'Mission count incremented');
  
  $member->add_mission();
  is($member->missions, 2, 'Mission count incremented again');
  
  # Test that missions can't be added after final disposition
  $member->set_disposition('KIA');
  $member->add_mission();
  is($member->missions, 2, 'Mission count not incremented after final disposition');
}

sub test_add_kills {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'tail_gunner',
  );
  
  $member->add_kills(2);
  is($member->kills, 2, 'Kills added correctly');
  
  $member->add_kills(3);
  is($member->kills, 5, 'Kills accumulated correctly');
  
  # Test negative kills
  $member->add_kills(-1);
  is($member->kills, 5, 'Negative kills are ignored');
  
  # Test kills after final disposition
  $member->set_disposition('KIA');
  $member->add_kills(1);
  is($member->kills, 5, 'Kills not added after final disposition');
}

sub test_apply_wound {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  $member->apply_wound('light');
  is($member->wound_status, 'light', 'Light wound applied');
  
  $member->apply_wound('serious');
  is($member->wound_status, 'serious', 'Serious wound applied');
  
  # Test that serious wounds don't downgrade
  $member->apply_wound('light');
  is($member->wound_status, 'serious', 'Serious wound not downgraded to light');
  
  # Test clearing wounds
  $member->apply_wound('none');
  is($member->wound_status, 'none', 'Wound cleared');
  
  # Test invalid wound
  $member->apply_wound('invalid');
  is($member->wound_status, 'none', 'Invalid wound ignored');
  
  # Test wound after final disposition
  $member->set_disposition('KIA');
  $member->apply_wound('light');
  is($member->wound_status, 'none', 'Wound not applied after final disposition');
}

sub test_set_disposition {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  $member->set_disposition('KIA');
  is($member->final_disposition, 'KIA', 'KIA disposition set');
  ok($member->has_final_disposition, 'Has final disposition');
  
  # Test all valid dispositions
  my @valid = qw(KIA DOW LAS IH BO-C);
  foreach my $disposition (@valid) {
    my $m = SoloGamer::QotS::CrewMember->new(
      name     => 'Test',
      position => 'pilot',
    );
    $m->set_disposition($disposition);
    is($m->final_disposition, $disposition, "$disposition set correctly");
  }
  
  # Test invalid disposition
  my $m = SoloGamer::QotS::CrewMember->new(
    name     => 'Test',
    position => 'pilot',
  );
  $m->set_disposition('INVALID');
  ok(!$m->has_final_disposition, 'Invalid disposition not set');
}

sub test_serialization {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name         => 'John Smith',
    position     => 'pilot',
    missions     => 5,
    kills        => 2,
    wound_status => 'light',
  );
  
  my $hash = $member->to_hash();
  isa_ok($hash, 'HASH', 'to_hash returns hash reference');
  is($hash->{name}, 'John Smith', 'Name serialized');
  is($hash->{position}, 'pilot', 'Position serialized');
  is($hash->{missions}, 5, 'Missions serialized');
  is($hash->{kills}, 2, 'Kills serialized');
  is($hash->{wound_status}, 'light', 'Wound status serialized');
  ok(!exists $hash->{final_disposition}, 'No final disposition in hash when not set');
  
  # Test with final disposition
  $member->set_disposition('KIA');
  $hash = $member->to_hash();
  is($hash->{final_disposition}, 'KIA', 'Final disposition serialized');
  
  # Test deserialization
  my $restored = SoloGamer::QotS::CrewMember->from_hash($hash);
  isa_ok($restored, 'SoloGamer::QotS::CrewMember', 'from_hash creates object');
  is($restored->name, 'John Smith', 'Name deserialized');
  is($restored->position, 'pilot', 'Position deserialized');
  is($restored->missions, 5, 'Missions deserialized');
  is($restored->kills, 2, 'Kills deserialized');
  is($restored->wound_status, 'light', 'Wound status deserialized');
  is($restored->final_disposition, 'KIA', 'Final disposition deserialized');
}

sub test_get_display_status {
  my $test = shift;
  
  my $member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
    missions => 5,
    kills    => 2,
  );
  
  my $status = $member->get_display_status();
  like($status, qr/pilot.*John Smith.*Missions:\s+5.*Kills:\s+2/, 
       'Display status shows all information');
  
  # Test with wound
  $member->apply_wound('light');
  $status = $member->get_display_status();
  like($status, qr/\[LIGHT WOUND\]/, 'Display shows wound status');
  
  # Test with final disposition
  $member->set_disposition('KIA');
  $status = $member->get_display_status();
  like($status, qr/\[KIA\]/, 'Display shows final disposition');
}

sub test_position_enum {
  my $test = shift;
  
  # Test valid positions
  my @valid_positions = qw(
    bombardier navigator pilot copilot engineer
    radio_operator ball_gunner port_waist_gunner
    starboard_waist_gunner tail_gunner
  );
  
  foreach my $position (@valid_positions) {
    lives_ok {
      SoloGamer::QotS::CrewMember->new(
        name     => 'Test',
        position => $position,
      );
    } "Valid position: $position";
  }
  
  # Test invalid position
  throws_ok {
    SoloGamer::QotS::CrewMember->new(
      name     => 'Test',
      position => 'invalid_position',
    );
  } qr/Validation failed/, 'Invalid position throws error';
}

__PACKAGE__->meta->make_immutable;
1;