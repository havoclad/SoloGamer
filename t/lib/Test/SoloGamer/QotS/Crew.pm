package Test::SoloGamer::QotS::Crew;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Slurp;

use SoloGamer::QotS::Crew;
use SoloGamer::QotS::CrewMember;

has 'test_dir' => (
  is      => 'ro',
  isa     => 'Str',
  default => sub { tempdir(CLEANUP => 1) },
);

sub test_setup {
  my $test = shift;
  
  # Create test name files for automated crew creation
  my $first_names = join("\n", qw(John James Robert William Richard David Edward Ronald Kenneth Paul));
  my $last_names = join("\n", qw(Smith Johnson Williams Brown Jones Miller Davis Wilson Moore Taylor));
  
  write_file('/games/QotS/1940s_male_first_names.txt', $first_names);
  write_file('/games/QotS/1940s_male_last_names.txt', $last_names);
}

sub test_constructor {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  isa_ok($crew, 'SoloGamer::QotS::Crew', 'Constructor creates correct object');
  isa_ok($crew->crew_members, 'HASH', 'Crew members is a hash');
  is($crew->automated, 1, 'Automated mode set correctly');
}

sub test_get_crew_member {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Initialize with test data
  my $test_member = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  $crew->crew_members->{pilot} = $test_member;
  
  my $member = $crew->get_crew_member('pilot');
  isa_ok($member, 'SoloGamer::QotS::CrewMember', 'get_crew_member returns CrewMember');
  is($member->name, 'John Smith', 'Correct member returned');
  
  # Test invalid position
  my $invalid = $crew->get_crew_member('invalid_position');
  ok(!defined $invalid, 'Invalid position returns undef');
  
  # Test no position
  my $no_pos = $crew->get_crew_member();
  ok(!defined $no_pos, 'No position returns undef');
}

sub test_get_active_crew {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Add some test crew members
  my @positions = qw(pilot copilot navigator bombardier);
  foreach my $position (@positions) {
    $crew->crew_members->{$position} = SoloGamer::QotS::CrewMember->new(
      name     => "Test $position",
      position => $position,
    );
  }
  
  my @active = $crew->get_active_crew();
  is(scalar(@active), 4, 'All crew members are active initially');
  
  # Set one as KIA
  $crew->crew_members->{pilot}->set_disposition('KIA');
  
  @active = $crew->get_active_crew();
  is(scalar(@active), 3, 'KIA member not in active crew');
  
  my @active_names = map { $_->position } @active;
  ok(!grep { $_ eq 'pilot' } @active_names, 'Pilot not in active list');
}

sub test_add_mission_for_active {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Add test crew members
  my @positions = qw(pilot copilot navigator);
  foreach my $position (@positions) {
    $crew->crew_members->{$position} = SoloGamer::QotS::CrewMember->new(
      name     => "Test $position",
      position => $position,
    );
  }
  
  # Set one as KIA
  $crew->crew_members->{navigator}->set_disposition('KIA');
  
  $crew->add_mission_for_active();
  
  is($crew->crew_members->{pilot}->missions, 1, 'Active pilot mission incremented');
  is($crew->crew_members->{copilot}->missions, 1, 'Active copilot mission incremented');
  is($crew->crew_members->{navigator}->missions, 0, 'KIA navigator mission not incremented');
}

sub test_replace_crew_member {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Add initial crew member
  $crew->crew_members->{pilot} = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
  );
  
  # Replace with custom name
  my $new_member = $crew->replace_crew_member('pilot', 'Bob Jones');
  isa_ok($new_member, 'SoloGamer::QotS::CrewMember', 'Replacement returns CrewMember');
  is($new_member->name, 'Bob Jones', 'Replacement has correct name');
  is($crew->crew_members->{pilot}->name, 'Bob Jones', 'Crew updated with replacement');
  
  # Test invalid position
  my $invalid = $crew->replace_crew_member('invalid_position', 'Test');
  ok(!defined $invalid, 'Invalid position returns undef');
}

sub test_serialization {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Add test crew members
  my @positions = qw(pilot copilot);
  foreach my $position (@positions) {
    $crew->crew_members->{$position} = SoloGamer::QotS::CrewMember->new(
      name     => "Test $position",
      position => $position,
      missions => 5,
      kills    => 2,
    );
  }
  
  my $hash = $crew->to_hash();
  isa_ok($hash, 'ARRAY', 'to_hash returns array reference');
  is(scalar(@$hash), 2, 'Array has correct number of members');
  
  # Test from_hash
  my $restored = SoloGamer::QotS::Crew->from_hash($hash, 1);
  isa_ok($restored, 'SoloGamer::QotS::Crew', 'from_hash creates Crew object');
  
  my $pilot = $restored->get_crew_member('pilot');
  is($pilot->name, 'Test pilot', 'Pilot restored correctly');
  is($pilot->missions, 5, 'Pilot missions restored');
  is($pilot->kills, 2, 'Pilot kills restored');
}

sub test_display_roster {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  # Add test crew members
  $crew->crew_members->{pilot} = SoloGamer::QotS::CrewMember->new(
    name     => 'John Smith',
    position => 'pilot',
    missions => 10,
    kills    => 0,
  );
  
  $crew->crew_members->{tail_gunner} = SoloGamer::QotS::CrewMember->new(
    name     => 'Bob Jones',
    position => 'tail_gunner',
    missions => 10,
    kills    => 5,
  );
  
  # Set one as KIA
  $crew->crew_members->{tail_gunner}->set_disposition('KIA');
  
  my $display = $crew->display_roster();
  like($display, qr/CREW ROSTER/, 'Display includes header');
  like($display, qr/John Smith.*10.*0/, 'Display shows pilot info');
  like($display, qr/Bob Jones.*10.*5.*\[KIA\]/, 'Display shows KIA crew member');
  like($display, qr/Active Crew:/, 'Display shows active count');
  like($display, qr/Casualties:.*Bob Jones \(KIA\)/, 'Display shows casualties');
}

sub test_position_helpers {
  my $test = shift;
  
  my $crew = SoloGamer::QotS::Crew->new(automated => 1);
  
  my @gunners = $crew->get_gunner_positions();
  is(scalar(@gunners), 4, 'Correct number of gunner positions');
  ok(grep { $_ eq 'tail_gunner' } @gunners, 'tail_gunner is a gunner position');
  ok(grep { $_ eq 'ball_gunner' } @gunners, 'ball_gunner is a gunner position');
  
  my @officers = $crew->get_officer_positions();
  is(scalar(@officers), 4, 'Correct number of officer positions');
  ok(grep { $_ eq 'pilot' } @officers, 'pilot is an officer position');
  ok(grep { $_ eq 'bombardier' } @officers, 'bombardier is an officer position');
}

__PACKAGE__->meta->make_immutable;
1;