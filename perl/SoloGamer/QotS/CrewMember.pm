package SoloGamer::QotS::CrewMember;

use strict;
use v5.20;

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

has 'final_disposition' => (
  is        => 'rw',
  isa       => 'Maybe[FinalDisposition]',
  default   => undef,
  predicate => 'has_final_disposition',
);

sub is_available {
  my $self = shift;
  return !defined($self->final_disposition);
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
}

sub apply_wound {
  my $self = shift;
  my $severity = shift;
  
  if (!$self->is_available) {
    $self->devel("Warning: Cannot wound crew member with final disposition: " . 
                 $self->name . " - " . ($self->final_disposition // 'unknown'));
    return;
  }
  
  unless ($severity && ($severity eq 'light' || $severity eq 'serious' || $severity eq 'none')) {
    $self->devel("Warning: Invalid wound severity: " . ($severity // 'undefined'));
    return;
  }
  
  my $current = $self->wound_status;
  
  if ($severity eq 'none') {
    $self->devel($self->name . " wound cleared");
    $self->wound_status('none');
    return;
  }
  
  if ($current eq 'serious' && $severity eq 'light') {
    $self->devel($self->name . " already has serious wound, not downgrading to light");
    return;
  }
  
  $self->wound_status($severity);
  $self->devel($self->name . " wounded: $severity");
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
}

sub to_hash {
  my $self = shift;
  
  my $hash = {
    name         => $self->name,
    position     => $self->position,
    missions     => $self->missions,
    kills        => $self->kills,
    wound_status => $self->wound_status,
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
    die "from_hash requires a hash reference";
  }
  
  my %args = (
    name         => $hash->{name},
    position     => $hash->{position},
    missions     => $hash->{missions} // 0,
    kills        => $hash->{kills} // 0,
    wound_status => $hash->{wound_status} // 'none',
  );
  
  if (exists $hash->{final_disposition} && defined $hash->{final_disposition}) {
    $args{final_disposition} = $hash->{final_disposition};
  }
  
  return $class->new(%args);
}

sub get_display_status {
  my $self = shift;
  
  my $status = sprintf("%-25s %-20s Missions: %3d  Kills: %3d",
    $self->position . ":",
    $self->name,
    $self->missions,
    $self->kills
  );
  
  if ($self->wound_status ne 'none') {
    $status .= "  [" . uc($self->wound_status) . " WOUND]";
  }
  
  if ($self->has_final_disposition && defined $self->final_disposition) {
    $status .= "  [" . $self->final_disposition . "]";
  }
  
  return $status;
}

__PACKAGE__->meta->make_immutable;
1;