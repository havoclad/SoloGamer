package SoloGamer::QotS::CombatState;

use strict;
use v5.20;

use Moose;
use namespace::autoclean;
use Carp;

with 'Logger';

has 'current_wave' => (
  is      => 'rw',
  isa     => 'Maybe[HashRef]',
  default => undef,
  clearer => 'clear_current_wave',
);

has 'active_fighters' => (
  is      => 'ro',
  isa     => 'ArrayRef[HashRef]',
  lazy    => 1,
  default => sub { [] },
  clearer => 'clear_active_fighters',
);

has 'defensive_fire_queue' => (
  is      => 'ro',
  isa     => 'ArrayRef[HashRef]',
  lazy    => 1,
  default => sub { [] },
  clearer => 'clear_defensive_fire_queue',
);

has 'successive_attacks' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} },
  clearer => 'clear_successive_attacks',
);

has 'ace_tracker' => (
  is      => 'ro',
  isa     => 'HashRef[Int]',
  lazy    => 1,
  default => sub { {} },
  clearer => 'clear_ace_tracker',
);

has 'fighter_damage' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} },
  clearer => 'clear_fighter_damage',
);

has 'wave_number' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has 'zone' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);

has 'fighter_cover' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'none',
);

has 'formation_position' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'middle',
);

sub reset_for_zone {
  my ($self, $zone) = @_;
  
  $self->zone($zone) if defined $zone;
  $self->wave_number(0);
  $self->clear_current_wave();
  $self->clear_active_fighters();
  $self->clear_defensive_fire_queue();
  $self->clear_successive_attacks();
  $self->clear_fighter_damage();
  
  $self->devel("Combat state reset for zone: " . ($zone || 'unknown'));
  
  return 1;
}

sub start_new_wave {
  my ($self, $wave_data) = @_;
  
  croak "Wave data required" unless defined $wave_data;
  
  $self->wave_number($self->wave_number + 1);
  $self->current_wave($wave_data);
  
  @{$self->active_fighters} = ();
  @{$self->defensive_fire_queue} = ();
  %{$self->successive_attacks} = ();
  %{$self->fighter_damage} = ();
  
  $self->devel("Started wave " . $self->wave_number);
  
  return $self->wave_number;
}

sub add_fighter {
  my ($self, $fighter_data) = @_;
  
  croak "Fighter data required" unless defined $fighter_data;
  croak "Fighter must have type" unless exists $fighter_data->{type};
  croak "Fighter must have position" unless exists $fighter_data->{position};
  
  my $fighter_id = $self->_generate_fighter_id($fighter_data);
  
  my $fighter = {
    id       => $fighter_id,
    type     => $fighter_data->{type},
    position => $fighter_data->{position},
    status   => $fighter_data->{status} || 'attacking',
    pilot    => $fighter_data->{pilot} || 'regular',
    attacks_made => 0,
  };
  
  push @{$self->active_fighters}, $fighter;
  
  $self->devel("Added $fighter->{type} fighter at $fighter->{position} (ID: $fighter_id)");
  
  return $fighter_id;
}

sub _generate_fighter_id {
  my ($self, $fighter_data) = @_;
  
  my $wave = $self->wave_number;
  my $type = substr($fighter_data->{type}, 0, 2);
  my $position = $fighter_data->{position};
  $position =~ s/[:\s]/_/g;
  
  my $count = 1;
  foreach my $existing (@{$self->active_fighters}) {
    if ($existing->{type} eq $fighter_data->{type} && 
        $existing->{position} eq $fighter_data->{position}) {
      $count++;
    }
  }
  
  return "W${wave}_${type}_${position}_${count}";
}

sub get_fighter {
  my ($self, $fighter_id) = @_;
  
  foreach my $fighter (@{$self->active_fighters}) {
    return $fighter if $fighter->{id} eq $fighter_id;
  }
  
  return undef;
}

sub update_fighter_status {
  my ($self, $fighter_id, $new_status) = @_;
  
  my $fighter = $self->get_fighter($fighter_id);
  return 0 unless $fighter;
  
  my $old_status = $fighter->{status};
  $fighter->{status} = $new_status;
  
  $self->devel("Fighter $fighter_id status changed from $old_status to $new_status");
  
  if ($new_status eq 'destroyed' || $new_status eq 'driven_off') {
    $self->_remove_fighter_from_queue($fighter_id);
  }
  
  return 1;
}

sub _remove_fighter_from_queue {
  my ($self, $fighter_id) = @_;
  
  my @new_queue = grep { $_->{fighter_id} ne $fighter_id } @{$self->defensive_fire_queue};
  @{$self->defensive_fire_queue} = @new_queue;
  
  delete $self->successive_attacks->{$fighter_id};
}

sub damage_fighter {
  my ($self, $fighter_id, $damage_type, $gunner_position) = @_;
  
  my $fighter = $self->get_fighter($fighter_id);
  return 0 unless $fighter;
  
  $damage_type ||= 'FCA';
  
  unless (exists $self->fighter_damage->{$fighter_id}) {
    $self->fighter_damage->{$fighter_id} = {
      FCA_hits  => 0,
      FBOA_hits => 0,
      status    => 'undamaged',
    };
  }
  
  my $damage = $self->fighter_damage->{$fighter_id};
  
  if ($damage_type eq 'FCA') {
    $damage->{FCA_hits}++;
    $self->devel("Fighter $fighter_id takes FCA hit (total: $damage->{FCA_hits})");
  } elsif ($damage_type eq 'FBOA') {
    $damage->{FBOA_hits}++;
    $self->update_fighter_status($fighter_id, 'breaking_off');
    $self->devel("Fighter $fighter_id takes FBOA hit and breaks off");
  } elsif ($damage_type eq 'destroyed') {
    $damage->{status} = 'destroyed';
    $self->update_fighter_status($fighter_id, 'destroyed');
    
    if (defined $gunner_position) {
      $self->record_kill($gunner_position);
    }
    
    $self->devel("Fighter $fighter_id destroyed!");
  }
  
  if ($damage->{FCA_hits} >= 2) {
    $damage->{status} = 'destroyed';
    $self->update_fighter_status($fighter_id, 'destroyed');
    
    if (defined $gunner_position) {
      $self->record_kill($gunner_position);
    }
    
    $self->devel("Fighter $fighter_id destroyed from cumulative damage!");
  }
  
  return 1;
}

sub record_kill {
  my ($self, $gunner_position) = @_;
  
  $self->ace_tracker->{$gunner_position} ||= 0;
  $self->ace_tracker->{$gunner_position}++;
  
  my $kills = $self->ace_tracker->{$gunner_position};
  $self->devel("$gunner_position gunner has $kills kill(s) this mission");
  
  if ($kills == 5) {
    $self->devel("$gunner_position gunner is now an ACE!");
  }
  
  return $kills;
}

sub add_to_defensive_fire_queue {
  my ($self, $fighter_id, $priority) = @_;
  
  my $fighter = $self->get_fighter($fighter_id);
  return 0 unless $fighter;
  
  $priority ||= $self->_calculate_fire_priority($fighter);
  
  push @{$self->defensive_fire_queue}, {
    fighter_id => $fighter_id,
    priority   => $priority,
    position   => $fighter->{position},
    type       => $fighter->{type},
  };
  
  @{$self->defensive_fire_queue} = sort { $a->{priority} <=> $b->{priority} } @{$self->defensive_fire_queue};
  
  $self->devel("Added $fighter_id to defensive fire queue with priority $priority");
  
  return 1;
}

sub _calculate_fire_priority {
  my ($self, $fighter) = @_;
  
  my $priority = 10;
  
  if ($fighter->{position} =~ /12/) {
    $priority = 1;
  } elsif ($fighter->{position} =~ /Vertical/) {
    $priority = 2;
  } elsif ($fighter->{position} =~ /1:30|10:30/) {
    $priority = 3;
  } elsif ($fighter->{position} =~ /3|9/) {
    $priority = 5;
  } elsif ($fighter->{position} eq '6') {
    $priority = 7;
  }
  
  $priority-- if $fighter->{type} eq 'Me110';
  
  return $priority;
}

sub get_next_defensive_target {
  my $self = shift;
  
  while (@{$self->defensive_fire_queue}) {
    my $target = shift @{$self->defensive_fire_queue};
    my $fighter = $self->get_fighter($target->{fighter_id});
    
    if ($fighter && $fighter->{status} eq 'attacking') {
      return $target;
    }
  }
  
  return undef;
}

sub record_successive_attack {
  my ($self, $fighter_id, $attack_number) = @_;
  
  my $fighter = $self->get_fighter($fighter_id);
  return 0 unless $fighter;
  
  $attack_number ||= $fighter->{attacks_made} + 1;
  
  if ($attack_number > 3) {
    $self->devel("Fighter $fighter_id already made maximum attacks");
    return 0;
  }
  
  $self->successive_attacks->{$fighter_id} = $attack_number;
  $fighter->{attacks_made} = $attack_number;
  
  $self->devel("Fighter $fighter_id recorded successive attack #$attack_number");
  
  return $attack_number;
}

sub can_make_successive_attack {
  my ($self, $fighter_id) = @_;
  
  my $fighter = $self->get_fighter($fighter_id);
  return 0 unless $fighter;
  
  return 0 if $fighter->{status} ne 'attacking';
  return 0 if $fighter->{attacks_made} >= 3;
  
  return 1;
}

sub get_active_fighter_count {
  my $self = shift;
  
  my $count = 0;
  foreach my $fighter (@{$self->active_fighters}) {
    $count++ if $fighter->{status} eq 'attacking';
  }
  
  return $count;
}

sub get_destroyed_fighter_count {
  my $self = shift;
  
  my $count = 0;
  foreach my $fighter (@{$self->active_fighters}) {
    $count++ if $fighter->{status} eq 'destroyed';
  }
  
  return $count;
}

sub get_kill_summary {
  my $self = shift;
  
  my %summary;
  
  foreach my $position (keys %{$self->ace_tracker}) {
    my $kills = $self->ace_tracker->{$position};
    $summary{$position} = {
      kills => $kills,
      ace   => $kills >= 5 ? 1 : 0,
    };
  }
  
  return \%summary;
}

sub wave_in_progress {
  my $self = shift;
  
  return defined $self->current_wave && $self->get_active_fighter_count() > 0;
}

sub complete_wave {
  my $self = shift;
  
  unless (defined $self->current_wave) {
    $self->devel("No wave to complete");
    return 0;
  }
  
  my $active = $self->get_active_fighter_count();
  if ($active > 0) {
    $self->devel("Cannot complete wave - $active fighters still active");
    return 0;
  }
  
  $self->clear_current_wave();
  $self->devel("Wave " . $self->wave_number . " completed");
  
  return 1;
}

__PACKAGE__->meta->make_immutable;
1;