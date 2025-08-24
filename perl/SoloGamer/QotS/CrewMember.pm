package SoloGamer::QotS::CrewMember;

use v5.42;

use Carp;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with 'Logger';

enum 'CrewPosition' => [qw(
  bombardier
  navigator
  pilot
  copilot
  engineer
  radio_operator
  ball_gunner
  port_waist_gunner
  starboard_waist_gunner
  tail_gunner
)];

enum 'WoundStatus' => [qw(
  none
  light
  serious
)];

enum 'FrostbiteStatus' => [qw(
  none
  light
  serious
)];

enum 'FinalDisposition' => [qw(
  KIA
  DOW
  LAS
  IH
  BO-C
)];

has 'name' => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has 'position' => (
  is       => 'ro',
  isa      => 'CrewPosition',
  required => 1,
);

has 'current_position' => (
  is       => 'rw',
  isa      => 'CrewPosition',
  lazy     => 1,
  builder  => '_build_current_position',
);

has 'missions' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has 'kills' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has 'wound_status' => (
  is      => 'rw',
  isa     => 'WoundStatus',
  default => 'none',
);

has 'frostbite_status' => (
  is      => 'rw',
  isa     => 'FrostbiteStatus',
  default => 'none',
);

has 'wounds' => (
  is      => 'ro',
  isa     => 'ArrayRef[HashRef]',
  default => sub { [] },
);

has 'final_disposition' => (
  is        => 'rw',
  isa       => 'Maybe[FinalDisposition]',
  default   => undef,
  predicate => 'has_final_disposition',
);

sub _build_current_position {
  my $self = shift;
  return $self->position;
}

sub is_available {
  my $self = shift;
  return !defined($self->final_disposition);
}

sub is_incapacitated {
  my $self = shift;
  
  return 1 if defined($self->final_disposition);
  return 1 if $self->wound_status eq 'serious';
  return 1 if $self->frostbite_status eq 'serious';
  
  return 0;
}

sub can_operate_gun {
  my $self = shift;
  
  return 0 if $self->is_incapacitated();
  return 0 if $self->wound_status eq 'serious';
  
  return 1;
}

sub add_mission {
  my $self = shift;
  
  if (!$self->is_available) {
    $self->devel("Warning: Cannot add mission to crew member with final disposition: " . 
                 $self->name . " - " . ($self->final_disposition // 'unknown'));
    return;
  }
  
  $self->missions($self->missions + 1);
  $self->devel("Added mission for " . $self->name . ", total: " . $self->missions);
  return;
}

sub add_kills {
  my $self = shift;
  my $count = shift || 0;
  
  if ($count < 0) {
    $self->devel("Warning: Cannot add negative kills");
    return;
  }
  
  if (!$self->is_available) {
    $self->devel("Warning: Cannot add kills to crew member with final disposition: " . 
                 $self->name . " - " . ($self->final_disposition // 'unknown'));
    return;
  }
  
  $self->kills($self->kills + $count);
  $self->devel("Added $count kills for " . $self->name . ", total: " . $self->kills);
  return;
}

sub apply_wound {
  my $self = shift;
  my $severity = shift;
  my $location = shift || 'unspecified';
  
  if (!$self->is_available) {
    $self->devel("Warning: Cannot wound crew member with final disposition: " . 
                 $self->name . " - " . ($self->final_disposition // 'unknown'));
    return;
  }
  
  unless ($severity && ($severity eq 'light' || $severity eq 'serious' || $severity eq 'none' || $severity eq 'mortal')) {
    $self->devel("Warning: Invalid wound severity: " . ($severity // 'undefined'));
    return;
  }
  
  my $current = $self->wound_status;
  
  if ($severity eq 'none') {
    $self->devel($self->name . " wound cleared");
    $self->wound_status('none');
    return;
  }
  
  if ($severity eq 'mortal') {
    $self->set_disposition('KIA');
    $self->wound_status('serious');
    push @{$self->wounds}, {
      severity => 'mortal',
      location => $location,
      turn => 'current'
    };
    $self->devel($self->name . " mortally wounded - KIA");
    return;
  }
  
  if ($current eq 'serious' && $severity eq 'serious') {
    $self->set_disposition('KIA');
    $self->devel($self->name . " second serious wound - KIA");
    return;
  }
  
  if ($current eq 'serious' && $severity eq 'light') {
    $self->devel($self->name . " already has serious wound, not downgrading to light");
    return;
  }
  
  $self->wound_status($severity);
  push @{$self->wounds}, {
    severity => $severity,
    location => $location,
    turn => 'current'
  };
  $self->devel($self->name . " wounded: $severity at $location");
  return;
}

sub apply_frostbite {
  my $self = shift;
  my $severity = shift;
  
  if (!$self->is_available) {
    $self->devel("Warning: Cannot apply frostbite to crew member with final disposition: " . 
                 $self->name . " - " . ($self->final_disposition // 'unknown'));
    return;
  }
  
  unless ($severity && ($severity eq 'light' || $severity eq 'serious' || $severity eq 'none')) {
    $self->devel("Warning: Invalid frostbite severity: " . ($severity // 'undefined'));
    return;
  }
  
  my $current = $self->frostbite_status;
  
  if ($severity eq 'none') {
    $self->devel($self->name . " frostbite cleared");
    $self->frostbite_status('none');
    return;
  }
  
  if ($current eq 'serious' && $severity eq 'light') {
    $self->devel($self->name . " already has serious frostbite, not downgrading to light");
    return;
  }
  
  $self->frostbite_status($severity);
  $self->devel($self->name . " frostbite: $severity");
  return;
}

sub move_to_position {
  my $self = shift;
  my $new_position = shift;
  
  unless ($new_position && grep { $_ eq $new_position } qw(bombardier navigator pilot copilot engineer radio_operator ball_gunner port_waist_gunner starboard_waist_gunner tail_gunner)) {
    $self->devel("Warning: Invalid position: " . ($new_position // 'undefined'));
    return 0;
  }
  
  if ($self->is_incapacitated()) {
    $self->devel("Warning: Incapacitated crew member cannot move: " . $self->name);
    return 0;
  }
  
  my $old_position = $self->current_position;
  $self->current_position($new_position);
  $self->devel($self->name . " moved from $old_position to $new_position");
  
  return 1;
}

sub set_disposition {
  my $self = shift;
  my $status = shift;
  
  unless ($status && grep { $_ eq $status } qw(KIA DOW LAS IH BO-C)) {
    $self->devel("Warning: Invalid final disposition: " . ($status // 'undefined'));
    return;
  }
  
  $self->final_disposition($status);
  $self->devel($self->name . " final disposition: $status");
  return;
}

sub to_hash {
  my $self = shift;
  
  my $hash = {
    name             => $self->name,
    position         => $self->position,
    current_position => $self->current_position,
    missions         => $self->missions,
    kills            => $self->kills,
    wound_status     => $self->wound_status,
    frostbite_status => $self->frostbite_status,
    wounds           => $self->wounds,
  };
  
  if ($self->has_final_disposition && defined $self->final_disposition) {
    $hash->{final_disposition} = $self->final_disposition;
  }
  
  return $hash;
}

sub from_hash {
  my $class = shift;
  my $hash = shift;
  
  unless ($hash && ref($hash) eq 'HASH') {
    croak 'from_hash requires a hash reference';
  }
  
  my %args = (
    name             => $hash->{name},
    position         => $hash->{position},
    missions         => $hash->{missions} // 0,
    kills            => $hash->{kills} // 0,
    wound_status     => $hash->{wound_status} // 'none',
    frostbite_status => $hash->{frostbite_status} // 'none',
  );
  
  if (exists $hash->{current_position} && defined $hash->{current_position}) {
    $args{current_position} = $hash->{current_position};
  }
  
  if (exists $hash->{wounds} && ref($hash->{wounds}) eq 'ARRAY') {
    $args{wounds} = $hash->{wounds};
  }
  
  if (exists $hash->{final_disposition} && defined $hash->{final_disposition}) {
    $args{final_disposition} = $hash->{final_disposition};
  }
  
  return $class->new(%args);
}

sub get_display_status {
  my $self = shift;
  
  my $position_str = $self->position;
  if ($self->current_position ne $self->position) {
    $position_str .= " (at " . $self->current_position . ")";
  }
  
  my $status = sprintf("%-30s %-20s Missions: %3d  Kills: %3d",
    $position_str . ":",
    $self->name,
    $self->missions,
    $self->kills
  );
  
  if ($self->wound_status ne 'none') {
    $status .= "  [" . uc($self->wound_status) . " WOUND]";
  }
  
  if ($self->frostbite_status ne 'none') {
    $status .= "  [" . uc($self->frostbite_status) . " FROSTBITE]";
  }
  
  if ($self->has_final_disposition && defined $self->final_disposition) {
    $status .= "  [" . $self->final_disposition . "]";
  }
  
  return $status;
}

__PACKAGE__->meta->make_immutable;
1;