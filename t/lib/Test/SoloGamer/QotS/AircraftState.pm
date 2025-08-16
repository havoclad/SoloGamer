package Test::SoloGamer::QotS::AircraftState;

use v5.42;

use Test::Class::Moose;
use Test::Exception;

use SoloGamer::QotS::AircraftState;

sub test_constructor {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  isa_ok($state, 'SoloGamer::QotS::AircraftState', 'Constructor creates correct object');
  
  isa_ok($state->engines, 'HASH', 'Engines is a hash');
  is(scalar keys %{$state->engines}, 4, 'Four engines initialized');
  
  isa_ok($state->control_surfaces, 'HASH', 'Control surfaces is a hash');
  ok(exists $state->control_surfaces->{rudder}, 'Rudder exists');
  ok(exists $state->control_surfaces->{elevators}, 'Elevators exist');
  ok(exists $state->control_surfaces->{ailerons}, 'Ailerons exist');
  
  isa_ok($state->fuel_system, 'HASH', 'Fuel system is a hash');
  isa_ok($state->fuel_system->{tanks}, 'HASH', 'Fuel tanks is a hash');
  is(scalar keys %{$state->fuel_system->{tanks}}, 5, 'Five fuel tank locations');
  
  isa_ok($state->guns, 'HASH', 'Guns is a hash');
  is(scalar keys %{$state->guns}, 8, 'Eight gun positions');
  
  isa_ok($state->structural, 'HASH', 'Structural is a hash');
  isa_ok($state->bomb_bay, 'HASH', 'Bomb bay is a hash');
  isa_ok($state->navigation, 'HASH', 'Navigation is a hash');
  isa_ok($state->oxygen, 'HASH', 'Oxygen is a hash');
  isa_ok($state->heating, 'HASH', 'Heating is a hash');
}

sub test_engine_damage {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->engines->{1}->{status}, 'operational', 'Engine 1 starts operational');
  
  my $status = $state->damage_engine(1, 'runaway');
  is($status, 'runaway', 'damage_engine returns correct status');
  is($state->engines->{1}->{status}, 'runaway', 'Engine 1 marked as runaway');
  
  $state->damage_engine(2, 'oil_tank');
  is($state->engines->{2}->{status}, 'failing', 'Engine 2 failing after oil tank hit');
  is($state->engines->{2}->{oil_tank}, 'damaged', 'Engine 2 oil tank damaged');
  
  $state->damage_engine(3, 'fire');
  is($state->engines->{3}->{status}, 'on_fire', 'Engine 3 on fire');
  
  $state->damage_engine(4, 'out');
  is($state->engines->{4}->{status}, 'out', 'Engine 4 out');
  
  $state->damage_engine(1, 'supercharger');
  is($state->engines->{1}->{supercharger}, 'damaged', 'Engine 1 supercharger damaged');
  
  dies_ok { $state->damage_engine(5, 'out') } 'Invalid engine number throws error';
}

sub test_control_surfaces {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->control_surfaces->{rudder}->{status}, 'operational', 'Rudder starts operational');
  is($state->control_surfaces->{rudder}->{damage_level}, 0, 'Rudder damage level starts at 0');
  
  my $status = $state->damage_control_surface('rudder', 1);
  is($state->control_surfaces->{rudder}->{damage_level}, 1, 'Rudder damage level increased');
  is($status, 'operational', 'Rudder still operational with minor damage');
  
  $state->damage_control_surface('rudder', 1);
  is($state->control_surfaces->{rudder}->{damage_level}, 2, 'Rudder damage level at 2');
  is($state->control_surfaces->{rudder}->{status}, 'damaged', 'Rudder damaged at level 2');
  
  $state->damage_control_surface('rudder', 1);
  is($state->control_surfaces->{rudder}->{damage_level}, 3, 'Rudder damage level at 3');
  is($state->control_surfaces->{rudder}->{status}, 'inoperable', 'Rudder inoperable at level 3');
  
  $state->damage_control_surface('elevators', 3);
  is($state->control_surfaces->{elevators}->{status}, 'inoperable', 'Elevators inoperable with severe damage');
  
  dies_ok { $state->damage_control_surface('invalid', 1) } 'Invalid control surface throws error';
}

sub test_fuel_system {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  my $tank = $state->fuel_system->{tanks}->{port_outer};
  is($tank->{status}, 'intact', 'Port outer tank starts intact');
  is($tank->{fuel_remaining}, 100, 'Tank starts with 100% fuel');
  is($tank->{self_sealing}, 1, 'Tank is self-sealing');
  
  my $status = $state->hit_fuel_tank('port_outer', 'leak');
  is($status, 'self_sealed', 'Self-sealing tank self-seals on first hit');
  is($state->fuel_system->{tanks}->{port_outer}->{status}, 'self_sealed', 'Tank status updated');
  
  $state->hit_fuel_tank('port_outer', 'leak');
  is($state->fuel_system->{tanks}->{port_outer}->{status}, 'leaking', 'Second hit causes leak');
  
  $state->hit_fuel_tank('starboard_inner', 'fire');
  is($state->fuel_system->{tanks}->{starboard_inner}->{status}, 'on_fire', 'Tank on fire');
  
  $state->hit_fuel_tank('port_inner', 'explosion');
  is($state->fuel_system->{tanks}->{port_inner}->{status}, 'exploded', 'Tank exploded');
  
  is($state->fuel_system->{tanks}->{tokyo_tanks}->{status}, 'not_installed', 'Tokyo tanks not installed');
  
  dies_ok { $state->hit_fuel_tank('invalid_tank', 'leak') } 'Invalid tank location throws error';
}

sub test_gun_status {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->guns->{nose}->{status}, 'operational', 'Nose gun starts operational');
  is($state->guns->{nose}->{jammed}, 0, 'Nose gun not jammed');
  is($state->guns->{nose}->{ammo}, 1000, 'Nose gun has 1000 rounds');
  
  ok($state->jam_gun('nose'), 'Jam gun returns true');
  is($state->guns->{nose}->{status}, 'jammed', 'Nose gun jammed');
  is($state->guns->{nose}->{jammed}, 1, 'Jammed flag set');
  
  ok($state->unjam_gun('nose'), 'Unjam gun returns true');
  is($state->guns->{nose}->{status}, 'operational', 'Nose gun operational again');
  is($state->guns->{nose}->{jammed}, 0, 'Jammed flag cleared');
  
  ok($state->destroy_gun('port_cheek'), 'Destroy gun returns true');
  is($state->guns->{port_cheek}->{status}, 'destroyed', 'Port cheek gun destroyed');
  
  ok(!$state->unjam_gun('port_cheek'), 'Cannot unjam destroyed gun');
  
  is($state->guns->{top_turret}->{twin}, 1, 'Top turret is twin gun');
  is($state->guns->{ball_turret}->{twin}, 1, 'Ball turret is twin gun');
  is($state->guns->{tail}->{twin}, 1, 'Tail gun is twin gun');
  
  dies_ok { $state->jam_gun('invalid_gun') } 'Invalid gun position throws error';
}

sub test_structural_damage {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->structural->{nose}->{hits}, 0, 'Nose starts with 0 hits');
  is($state->structural->{nose}->{superficial_damage}, 0, 'Nose starts with 0 superficial damage');
  
  my $hits = $state->add_structural_damage('nose', 'hit');
  is($hits, 1, 'add_structural_damage returns hit count');
  is($state->structural->{nose}->{hits}, 1, 'Nose has 1 hit');
  
  $state->add_structural_damage('nose', 'superficial');
  is($state->structural->{nose}->{superficial_damage}, 1, 'Nose has 1 superficial damage');
  is($state->structural->{nose}->{hits}, 1, 'Hit count unchanged');
  
  $state->add_structural_damage('pilot');
  is($state->structural->{pilot}->{hits}, 1, 'Default damage type is hit');
  
  $state->add_structural_damage('port_wing', 'hit');
  is($state->structural->{port_wing}->{hits}, 1, 'Wing can take hits');
  is($state->structural->{port_wing}->{aileron_cables}, 'intact', 'Aileron cables intact');
  
  dies_ok { $state->add_structural_damage('invalid_compartment') } 'Invalid compartment throws error';
}

sub test_damage_accumulation {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  ok(!$state->has_engine_damage(), 'No engine damage initially');
  is($state->count_engines_out(), 0, 'No engines out initially');
  
  $state->damage_engine(1, 'out');
  ok($state->has_engine_damage(), 'Has engine damage after damaging engine');
  is($state->count_engines_out(), 1, 'One engine out');
  
  $state->damage_engine(2, 'out');
  is($state->count_engines_out(), 2, 'Two engines out');
  
  $state->engines->{3}->{status} = 'feathered';
  is($state->count_engines_out(), 3, 'Feathered engines count as out');
  
  ok(!$state->has_control_damage(), 'No control damage initially');
  $state->damage_control_surface('rudder', 2);
  ok($state->has_control_damage(), 'Has control damage after damaging rudder');
  
  is($state->count_fuel_leaks(), 0, 'No fuel leaks initially');
  $state->hit_fuel_tank('port_outer', 'leak');
  is($state->count_fuel_leaks(), 0, 'Self-sealed tank doesn\'t count as leak');
  $state->hit_fuel_tank('port_outer', 'leak');
  is($state->count_fuel_leaks(), 1, 'One fuel leak');
  $state->hit_fuel_tank('starboard_outer', 'leak');
  $state->hit_fuel_tank('starboard_outer', 'leak');
  is($state->count_fuel_leaks(), 2, 'Two fuel leaks');
}

sub test_ammo_management {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->guns->{nose}->{ammo}, 1000, 'Nose gun starts with 1000 rounds');
  
  ok($state->use_ammo('nose', 10), 'use_ammo returns true when ammo available');
  is($state->guns->{nose}->{ammo}, 990, 'Ammo decremented correctly');
  
  ok($state->use_ammo('nose'), 'Default ammo use is 1');
  is($state->guns->{nose}->{ammo}, 989, 'Ammo decremented by 1');
  
  $state->guns->{nose}->{ammo} = 5;
  ok($state->use_ammo('nose', 5), 'Can use last of ammo');
  is($state->guns->{nose}->{ammo}, 0, 'Ammo at 0');
  
  ok(!$state->use_ammo('nose', 1), 'use_ammo returns false when out of ammo');
  is($state->guns->{nose}->{status}, 'out_of_ammo', 'Gun marked as out of ammo');
  
  dies_ok { $state->use_ammo('invalid_gun', 10) } 'Invalid gun position throws error';
}

sub test_operational_guns {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  my @operational = $state->get_operational_guns();
  is(scalar @operational, 8, 'All 8 guns operational initially');
  
  $state->jam_gun('nose');
  @operational = $state->get_operational_guns();
  is(scalar @operational, 7, '7 guns operational after jamming one');
  ok(!grep { $_ eq 'nose' } @operational, 'Nose gun not in operational list');
  
  $state->unjam_gun('nose');
  @operational = $state->get_operational_guns();
  is(scalar @operational, 8, 'All guns operational after unjamming');
  
  $state->destroy_gun('tail');
  $state->guns->{port_waist}->{status} = 'out_of_ammo';
  @operational = $state->get_operational_guns();
  is(scalar @operational, 6, '6 guns operational');
  ok(!grep { $_ eq 'tail' } @operational, 'Destroyed gun not operational');
  ok(!grep { $_ eq 'port_waist' } @operational, 'Out of ammo gun not operational');
}

sub test_serialization {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  $state->damage_engine(1, 'out');
  $state->damage_control_surface('rudder', 2);
  $state->hit_fuel_tank('port_outer', 'leak');
  $state->jam_gun('nose');
  $state->add_structural_damage('pilot', 'hit');
  $state->use_ammo('tail', 100);
  
  my $hash = $state->to_hash();
  isa_ok($hash, 'HASH', 'to_hash returns hash reference');
  ok(exists $hash->{engines}, 'Hash contains engines');
  ok(exists $hash->{control_surfaces}, 'Hash contains control_surfaces');
  ok(exists $hash->{fuel_system}, 'Hash contains fuel_system');
  ok(exists $hash->{guns}, 'Hash contains guns');
  ok(exists $hash->{structural}, 'Hash contains structural');
  
  is($hash->{engines}->{1}->{status}, 'out', 'Engine damage persisted');
  is($hash->{control_surfaces}->{rudder}->{status}, 'damaged', 'Control damage persisted');
  is($hash->{fuel_system}->{tanks}->{port_outer}->{status}, 'self_sealed', 'Fuel tank status persisted');
  is($hash->{guns}->{nose}->{jammed}, 1, 'Gun jam persisted');
  is($hash->{structural}->{pilot}->{hits}, 1, 'Structural damage persisted');
  is($hash->{guns}->{tail}->{ammo}, 900, 'Ammo count persisted');
  
  my $restored = SoloGamer::QotS::AircraftState->from_hash($hash);
  isa_ok($restored, 'SoloGamer::QotS::AircraftState', 'from_hash returns AircraftState object');
  
  is($restored->engines->{1}->{status}, 'out', 'Engine damage restored');
  is($restored->control_surfaces->{rudder}->{status}, 'damaged', 'Control damage restored');
  is($restored->fuel_system->{tanks}->{port_outer}->{status}, 'self_sealed', 'Fuel tank status restored');
  is($restored->guns->{nose}->{jammed}, 1, 'Gun jam restored');
  is($restored->structural->{pilot}->{hits}, 1, 'Structural damage restored');
  is($restored->guns->{tail}->{ammo}, 900, 'Ammo count restored');
  
  is($restored->count_engines_out(), 1, 'Engine count correct after restore');
  ok($restored->has_control_damage(), 'Control damage detected after restore');
}

sub test_bomb_bay_systems {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->bomb_bay->{doors}->{status}, 'operational', 'Bomb bay doors operational');
  is($state->bomb_bay->{bomb_controls}->{status}, 'operational', 'Bomb controls operational');
  is($state->bomb_bay->{bomb_release}->{status}, 'operational', 'Bomb release operational');
  is($state->bomb_bay->{bombs_remaining}, 12, '12 bombs loaded');
  is($state->bomb_bay->{bomb_load_type}, '500lb', '500lb bombs loaded');
  is($state->bomb_bay->{incendiaries}, 0, 'No incendiaries');
}

sub test_navigation_equipment {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  my $nav = $state->navigation->{equipment};
  is($nav->{compass}->{status}, 'operational', 'Compass operational');
  is($nav->{drift_meter}->{status}, 'operational', 'Drift meter operational');
  is($nav->{altimeter}->{status}, 'operational', 'Altimeter operational');
  is($nav->{airspeed}->{status}, 'operational', 'Airspeed indicator operational');
  is($nav->{radio_compass}->{status}, 'operational', 'Radio compass operational');
  is($state->navigation->{accuracy_modifier}, 0, 'No navigation accuracy modifier');
}

sub test_oxygen_system {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->oxygen->{system}->{status}, 'operational', 'Oxygen system operational');
  is($state->oxygen->{system}->{pressure}, 100, 'Oxygen at 100% pressure');
  
  my $masks = $state->oxygen->{masks};
  is(scalar keys %{$masks}, 9, '9 oxygen mask positions');
  
  foreach my $position (keys %{$masks}) {
    is($masks->{$position}->{status}, 'operational', "$position oxygen mask operational");
  }
}

sub test_heating_system {
  my $test = shift;
  
  my $state = SoloGamer::QotS::AircraftState->new();
  
  is($state->heating->{system}->{status}, 'operational', 'Heating system operational');
  is($state->heating->{suits}->{all_crew}->{status}, 'operational', 'Heated suits operational');
  is($state->heating->{suits}->{all_crew}->{count}, 10, '10 heated suits available');
}

__PACKAGE__->meta->make_immutable;
1;