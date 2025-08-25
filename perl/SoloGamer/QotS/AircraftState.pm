package SoloGamer::QotS::AircraftState;

use v5.42;

use Moose;
use namespace::autoclean;
use Carp;

with 'Logger';

has 'engines' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_engines',
);

has 'control_surfaces' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_control_surfaces',
);

has 'fuel_system' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_fuel_system',
);

has 'guns' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_guns',
);

has 'structural' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_structural',
);

has 'bomb_bay' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_bomb_bay',
);

has 'navigation' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_navigation',
);

has 'oxygen' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_oxygen',
);

has 'heating' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_heating',
);

sub _build_engines {
  my $self = shift;
  
  return {
    1 => { position => 'port_outer',      status => 'operational', oil_tank => 'intact', supercharger => 'operational' },
    2 => { position => 'port_inner',      status => 'operational', oil_tank => 'intact', supercharger => 'operational' },
    3 => { position => 'starboard_inner', status => 'operational', oil_tank => 'intact', supercharger => 'operational' },
    4 => { position => 'starboard_outer', status => 'operational', oil_tank => 'intact', supercharger => 'operational' },
  };
}

sub _build_control_surfaces {
  my $self = shift;
  
  return {
    rudder        => { status => 'operational', damage_level => 0 },
    elevators     => { status => 'operational', damage_level => 0 },
    ailerons      => { status => 'operational', damage_level => 0 },
    trim_tabs     => { status => 'operational' },
    flaps         => { status => 'operational' },
    landing_gear  => { status => 'operational' },
  };
}

sub _build_fuel_system {
  my $self = shift;
  
  return {
    tanks => {
      port_outer      => { status => 'intact', fuel_remaining => 100, self_sealing => 1 },
      port_inner      => { status => 'intact', fuel_remaining => 100, self_sealing => 1 },
      starboard_inner => { status => 'intact', fuel_remaining => 100, self_sealing => 1 },
      starboard_outer => { status => 'intact', fuel_remaining => 100, self_sealing => 1 },
      tokyo_tanks     => { status => 'not_installed', fuel_remaining => 0 },
    },
    transfer_pumps => { status => 'operational' },
    fuel_lines     => { status => 'intact' },
  };
}

sub _build_guns {
  my $self = shift;
  
  return {
    nose            => { status => 'operational', ammo => 1000, jammed => 0 },
    port_cheek      => { status => 'operational', ammo => 400,  jammed => 0 },
    starboard_cheek => { status => 'operational', ammo => 400,  jammed => 0 },
    top_turret      => { status => 'operational', ammo => 1000, jammed => 0, twin => 1 },
    ball_turret     => { status => 'operational', ammo => 600,  jammed => 0, twin => 1 },
    port_waist      => { status => 'operational', ammo => 600,  jammed => 0 },
    starboard_waist => { status => 'operational', ammo => 600,  jammed => 0 },
    tail            => { status => 'operational', ammo => 1000, jammed => 0, twin => 1 },
  };
}

sub _build_structural {
  my $self = shift;
  
  return {
    nose      => { hits => 0, superficial_damage => 0 },
    pilot     => { hits => 0, superficial_damage => 0 },
    bomb_bay  => { hits => 0, superficial_damage => 0 },
    radio     => { hits => 0, superficial_damage => 0 },
    waist     => { hits => 0, superficial_damage => 0 },
    tail      => { hits => 0, superficial_damage => 0 },
    port_wing => { 
      hits => 0, 
      superficial_damage => 0,
      root_damage => 0,
      aileron_cables => 'intact'
    },
    starboard_wing => { 
      hits => 0, 
      superficial_damage => 0,
      root_damage => 0,
      aileron_cables => 'intact'
    },
  };
}

sub _build_bomb_bay {
  my $self = shift;
  
  return {
    doors            => { status => 'operational', jammed => 0 },
    bomb_controls    => { status => 'operational' },
    bomb_release     => { status => 'operational' },
    bombs_remaining  => 12,
    bomb_load_type   => '500lb',
    incendiaries     => 0,
  };
}

sub _build_navigation {
  my $self = shift;
  
  return {
    equipment => {
      compass      => { status => 'operational' },
      drift_meter  => { status => 'operational' },
      altimeter    => { status => 'operational' },
      airspeed     => { status => 'operational' },
      radio_compass => { status => 'operational' },
    },
    accuracy_modifier => 0,
  };
}

sub _build_oxygen {
  my $self = shift;
  
  return {
    system => { status => 'operational', pressure => 100 },
    masks  => {
      nose      => { status => 'operational' },
      pilot     => { status => 'operational' },
      copilot   => { status => 'operational' },
      engineer  => { status => 'operational' },
      radio     => { status => 'operational' },
      ball      => { status => 'operational' },
      waist_port => { status => 'operational' },
      waist_stbd => { status => 'operational' },
      tail      => { status => 'operational' },
    },
  };
}

sub _build_heating {
  my $self = shift;
  
  return {
    system => { status => 'operational' },
    suits  => {
      all_crew => { status => 'operational', count => 10 },
    },
  };
}

sub damage_engine {
  my ($self, $engine_num, $damage_type) = @_;
  
  croak "Invalid engine number: $engine_num" unless exists $self->engines->{$engine_num};
  
  my $engine = $self->engines->{$engine_num};
  
  SWITCH: for ($damage_type) {
    if (/runaway/xms) {
      $engine->{status} = 'runaway';
      $self->devel("Engine $engine_num is running away - must be feathered!");
      last SWITCH;
    }
    if (/oil_tank/xms) {
      $engine->{oil_tank} = 'damaged';
      $engine->{status} = 'failing';
      $self->devel("Engine $engine_num oil tank hit - engine will fail soon");
      last SWITCH;
    }
    if (/fire/xms) {
      $engine->{status} = 'on_fire';
      $self->devel("Engine $engine_num is on fire!");
      last SWITCH;
    }
    if (/out/xms) {
      $engine->{status} = 'out';
      $self->devel("Engine $engine_num is out");
      last SWITCH;
    }
    if (/supercharger/xms) {
      $engine->{supercharger} = 'damaged';
      $self->devel("Engine $engine_num supercharger damaged");
      last SWITCH;
    }
  }
  
  return $engine->{status};
}

sub damage_control_surface {
  my ($self, $surface, $severity) = @_;
  
  croak "Invalid control surface: $surface" unless exists $self->control_surfaces->{$surface};
  
  $severity //= 1;
  my $control = $self->control_surfaces->{$surface};
  
  $control->{damage_level} += $severity;
  
  if ($control->{damage_level} >= 3) {
    $control->{status} = 'inoperable';
    $self->devel("$surface is now inoperable!");
  } elsif ($control->{damage_level} >= 2) {
    $control->{status} = 'damaged';
    $self->devel("$surface is damaged");
  }
  
  return $control->{status};
}

sub hit_fuel_tank {
  my ($self, $tank_location, $hit_type) = @_;
  
  my $tanks = $self->fuel_system->{tanks};
  croak "Invalid tank location: $tank_location" unless exists $tanks->{$tank_location};
  
  my $tank = $tanks->{$tank_location};
  
  if ($hit_type eq 'leak') {
    if ($tank->{self_sealing} && $tank->{status} eq 'intact') {
      $tank->{status} = 'self_sealed';
      $self->devel("$tank_location tank self-sealed");
    } else {
      $tank->{status} = 'leaking';
      $self->devel("$tank_location tank is leaking fuel!");
    }
  } elsif ($hit_type eq 'fire') {
    $tank->{status} = 'on_fire';
    $self->devel("$tank_location tank is on fire!");
  } elsif ($hit_type eq 'explosion') {
    $tank->{status} = 'exploded';
    $self->devel("$tank_location tank exploded!");
  }
  
  return $tank->{status};
}

sub jam_gun {
  my ($self, $gun_position) = @_;
  
  croak "Invalid gun position: $gun_position" unless exists $self->guns->{$gun_position};
  
  $self->guns->{$gun_position}->{jammed} = 1;
  $self->guns->{$gun_position}->{status} = 'jammed';
  $self->devel("$gun_position gun jammed!");
  
  return 1;
}

sub unjam_gun {
  my ($self, $gun_position) = @_;
  
  croak "Invalid gun position: $gun_position" unless exists $self->guns->{$gun_position};
  
  my $gun = $self->guns->{$gun_position};
  
  if ($gun->{jammed} && $gun->{status} ne 'destroyed') {
    $gun->{jammed} = 0;
    $gun->{status} = 'operational';
    $self->devel("$gun_position gun unjammed");
    return 1;
  }
  
  return 0;
}

sub destroy_gun {
  my ($self, $gun_position) = @_;
  
  croak "Invalid gun position: $gun_position" unless exists $self->guns->{$gun_position};
  
  $self->guns->{$gun_position}->{status} = 'destroyed';
  $self->guns->{$gun_position}->{jammed} = 0;
  $self->devel("$gun_position gun destroyed!");
  
  return 1;
}

sub add_structural_damage {
  my ($self, $compartment, $damage_type) = @_;
  
  croak "Invalid compartment: $compartment" unless exists $self->structural->{$compartment};
  
  $damage_type //= 'hit';
  
  if ($damage_type eq 'superficial') {
    $self->structural->{$compartment}->{superficial_damage}++;
    $self->devel("Superficial damage to $compartment");
  } else {
    $self->structural->{$compartment}->{hits}++;
    $self->devel("Structural hit to $compartment");
  }
  
  return $self->structural->{$compartment}->{hits};
}

sub has_engine_damage {
  my $self = shift;
  
  foreach my $engine_num (keys %{$self->engines}) {
    my $status = $self->engines->{$engine_num}->{status};
    return 1 if $status ne 'operational';
  }
  
  return 0;
}

sub count_engines_out {
  my $self = shift;
  
  my $count = 0;
  foreach my $engine_num (keys %{$self->engines}) {
    my $status = $self->engines->{$engine_num}->{status};
    $count++ if $status eq 'out' || $status eq 'feathered';
  }
  
  return $count;
}

sub has_control_damage {
  my $self = shift;
  
  foreach my $surface (keys %{$self->control_surfaces}) {
    my $status = $self->control_surfaces->{$surface}->{status};
    return 1 if $status ne 'operational';
  }
  
  return 0;
}

sub count_fuel_leaks {
  my $self = shift;
  
  my $count = 0;
  my $tanks = $self->fuel_system->{tanks};
  
  foreach my $tank (keys %{$tanks}) {
    $count++ if $tanks->{$tank}->{status} eq 'leaking';
  }
  
  return $count;
}

sub get_operational_guns {
  my $self = shift;
  
  my @operational;
  foreach my $gun (keys %{$self->guns}) {
    push @operational, $gun if $self->guns->{$gun}->{status} eq 'operational';
  }
  
  return @operational;
}

sub use_ammo {
  my ($self, $gun_position, $amount) = @_;
  
  croak "Invalid gun position: $gun_position" unless exists $self->guns->{$gun_position};
  
  $amount //= 1;
  my $gun = $self->guns->{$gun_position};
  
  if ($gun->{ammo} >= $amount) {
    $gun->{ammo} -= $amount;
    return 1;
  } else {
    $gun->{ammo} = 0;
    $gun->{status} = 'out_of_ammo';
    $self->devel("$gun_position is out of ammo!");
    return 0;
  }
}

sub to_hash {
  my $self = shift;
  
  return {
    engines          => $self->engines,
    control_surfaces => $self->control_surfaces,
    fuel_system      => $self->fuel_system,
    guns             => $self->guns,
    structural       => $self->structural,
    bomb_bay         => $self->bomb_bay,
    navigation       => $self->navigation,
    oxygen           => $self->oxygen,
    heating          => $self->heating,
  };
}

sub from_hash {
  my ($class, $hash) = @_;
  
  my $self = $class->new();
  
  %{$self->engines}          = %{$hash->{engines}}          if exists $hash->{engines};
  %{$self->control_surfaces} = %{$hash->{control_surfaces}} if exists $hash->{control_surfaces};
  %{$self->fuel_system}      = %{$hash->{fuel_system}}      if exists $hash->{fuel_system};
  %{$self->guns}             = %{$hash->{guns}}             if exists $hash->{guns};
  %{$self->structural}       = %{$hash->{structural}}       if exists $hash->{structural};
  %{$self->bomb_bay}         = %{$hash->{bomb_bay}}         if exists $hash->{bomb_bay};
  %{$self->navigation}       = %{$hash->{navigation}}       if exists $hash->{navigation};
  %{$self->oxygen}           = %{$hash->{oxygen}}           if exists $hash->{oxygen};
  %{$self->heating}          = %{$hash->{heating}}          if exists $hash->{heating};
  
  return $self;
}

__PACKAGE__->meta->make_immutable;
1;