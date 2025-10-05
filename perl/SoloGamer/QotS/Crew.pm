package SoloGamer::QotS::Crew;

use v5.42;

use Carp;
use Moose;
use namespace::autoclean;

use SoloGamer::QotS::CrewMember;
use SoloGamer::QotS::CrewNamer;
use SoloGamer::Formatter;

with 'Logger';

has 'automated' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'automated',
  default  => 0,
);

has 'input_file' => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'input_file',
  default  => '',
);

has 'crew_members' => (
  is      => 'ro',
  isa     => 'HashRef[SoloGamer::QotS::CrewMember]',
  default => sub { {} },
);

has '_positions' => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [
    'bombardier',
    'navigator',
    'pilot',
    'copilot',
    'engineer',
    'radio_operator',
    'ball_gunner',
    'port_waist_gunner',
    'starboard_waist_gunner',
    'tail_gunner'
  ] },
);

has 'formatter' => (
  is      => 'ro',
  isa     => 'SoloGamer::Formatter',
  default => sub { SoloGamer::Formatter->new() },
  lazy    => 1,
);

sub BUILD {
  my $self = shift;
  my $args = shift;
  
  # Only initialize if we're not being created from from_hash
  # from_hash will handle initialization separately
  if (scalar keys %{$self->crew_members} == 0 && !exists $args->{skip_init}) {
    $self->initialize_crew();
  }
  return;
}

sub initialize_crew {
  my $self = shift;
  my $crew_data = shift;
  
  if ($crew_data) {
    $self->_initialize_from_data($crew_data);
  } else {
    $self->_initialize_new_crew();
  }
  return;
}

sub _initialize_from_data {
  my $self = shift;
  my $crew_data = shift;
  
  unless ($crew_data && ref($crew_data) eq 'ARRAY') {
    croak "initialize_from_data requires an array reference";
  }
  
  foreach my $member_data (@$crew_data) {
    my $member = SoloGamer::QotS::CrewMember->from_hash($member_data);
    $self->crew_members->{$member->position} = $member;
  }
  
  foreach my $position (@{$self->_positions}) {
    unless (exists $self->crew_members->{$position}) {
      $self->devel("Warning: Missing crew member for position: $position");
    }
  }
  return;
}

sub _initialize_new_crew {
  my $self = shift;
  
  my $namer = SoloGamer::QotS::CrewNamer->new(
    automated  => $self->automated,
    input_file => $self->input_file,
  );
  my $crew_names = $namer->prompt_for_crew_names($self->_positions);
  
  foreach my $crew_info (@$crew_names) {
    my $member = SoloGamer::QotS::CrewMember->new(
      name     => $crew_info->{name},
      position => $crew_info->{position},
    );
    $self->crew_members->{$crew_info->{position}} = $member;
  }
  
  $self->devel("Crew initialized with " . scalar(keys %{$self->crew_members}) . " members");
  return;
}

sub get_crew_member {
  my $self = shift;
  my $position = shift;
  
  unless ($position) {
    $self->devel("Warning: No position specified");
    return;
  }
  
  unless (grep { $_ eq $position } @{$self->_positions}) {
    $self->devel("Warning: Invalid position: $position");
    return;
  }
  
  return $self->crew_members->{$position};
}

sub get_active_crew {
  my $self = shift;
  
  my @active;
  foreach my $position (@{$self->_positions}) {
    my $member = $self->crew_members->{$position};
    if ($member && $member->is_available) {
      push @active, $member;
    }
  }
  
  return @active;
}

sub get_all_crew {
  my $self = shift;
  
  my @all;
  foreach my $position (@{$self->_positions}) {
    my $member = $self->crew_members->{$position};
    push @all, $member if $member;
  }
  
  return @all;
}

sub add_mission_for_active {
  my $self = shift;

  # Add mission credit for ALL crew members who started the mission
  # This includes those who were killed or wounded during the mission
  my @all = $self->get_all_crew();
  foreach my $member (@all) {
    $member->add_mission();
  }

  $self->devel("Added mission for " . scalar(@all) . " crew members");
  return;
}

sub replace_crew_member {
  my $self = shift;
  my $position = shift;
  my $new_name = shift;
  
  unless ($position && grep { $_ eq $position } @{$self->_positions}) {
    $self->devel("Warning: Invalid position for replacement: " . ($position // 'undefined'));
    return;
  }
  
  unless ($new_name) {
    my $namer = SoloGamer::QotS::CrewNamer->new(
      automated  => $self->automated,
      input_file => $self->input_file,
    );
    $new_name = $namer->get_random_name();
  }
  
  my $old_member = $self->crew_members->{$position};
  my $old_name = $old_member ? $old_member->name : 'vacant';
  
  my $new_member = SoloGamer::QotS::CrewMember->new(
    name     => $new_name,
    position => $position,
  );
  
  $self->crew_members->{$position} = $new_member;
  $self->devel("Replaced $position: $old_name -> $new_name");
  
  return $new_member;
}

sub to_hash {
  my $self = shift;
  
  my @crew_array;
  foreach my $position (@{$self->_positions}) {
    my $member = $self->crew_members->{$position};
    if ($member) {
      push @crew_array, $member->to_hash();
    }
  }
  
  return \@crew_array;
}

sub from_hash {
  my $class = shift;
  my $crew_data = shift;
  my $automated = shift // 0;
  
  my $crew = $class->new(automated => $automated, skip_init => 1);
  
  if ($crew_data && ref($crew_data) eq 'ARRAY') {
    $crew->initialize_crew($crew_data);
  }
  
  return $crew;
}

sub display_roster {
  my $self = shift;
  
  # Use formatter to create a nice boxed header like the Welcome header
  my $header = $self->formatter->box_header("CREW ROSTER", 70);
  my $output = "\n$header\n";
  
  foreach my $position (@{$self->_positions}) {
    my $member = $self->crew_members->{$position};
    if ($member) {
      $output .= $member->get_display_status() . "\n";
    } else {
      $output .= sprintf("%-25s VACANT\n", $position . ":");
    }
  }
  
  $output .= "=" x 70 . "\n";
  
  my @active = $self->get_active_crew();
  my $active_count = scalar(@active);
  my $total_count = scalar(@{$self->_positions});
  
  $output .= "Active Crew: $active_count / $total_count\n";
  
  if ($active_count < $total_count) {
    my @casualties;
    foreach my $position (@{$self->_positions}) {
      my $member = $self->crew_members->{$position};
      if ($member && !$member->is_available && defined $member->final_disposition) {
        push @casualties, $member->name . " (" . $member->final_disposition . ")";
      }
    }
    if (@casualties) {
      $output .= "Casualties: " . join(", ", @casualties) . "\n";
    }
  }
  
  return $output;
}

sub get_gunner_positions {
  my $self = shift;
  
  return qw(
    ball_gunner
    port_waist_gunner
    starboard_waist_gunner
    tail_gunner
  );
}

sub get_officer_positions {
  my $self = shift;

  return qw(
    bombardier
    navigator
    pilot
    copilot
  );
}

sub heal_light_wounds {
  my $self = shift;

  # Light wounds heal between missions automatically
  my @all = $self->get_all_crew();
  my $healed_count = 0;

  foreach my $member (@all) {
    next unless $member;
    next unless $member->is_available;

    if ($member->wound_status eq 'light') {
      $member->apply_wound('none');
      $self->devel($member->name . ' light wound healed between missions');
      $healed_count++;
    }
  }

  if ($healed_count > 0) {
    $self->devel("Healed $healed_count light wound(s)");
  }

  return $healed_count;
}

sub process_serious_wounds {
  my $self = shift;
  my $game = shift;  # Need game object for dice rolling and output

  unless ($game) {
    $self->devel('Warning: process_serious_wounds requires game object');
    return 0;
  }

  my @all = $self->get_all_crew();
  my $processed_count = 0;

  foreach my $member (@all) {
    next unless $member;
    next unless $member->is_available;
    next unless $member->wound_status eq 'serious';

    # Roll 1d6 for survival per BL-4 subnote b)
    my $roll = $game->roll_dice('1d6');
    my $name = $member->name;
    my $position = $member->position;

    if ($roll == 1) {
      # Rapid recovery - may fly next mission
      $member->apply_wound('none');
      $game->buffer_success("$name: Survival roll $roll - Rapid recovery, cleared for next mission");
      $self->devel("$name rapid recovery from serious wound");
    }
    elsif ($roll >= 2 && $roll <= 5) {
      # Recovery but cannot fly more missions - mark as IH (Invalidated Home)
      $member->set_disposition('IH');
      $game->buffer_info("$name: Survival roll $roll - Recovered but invalidated home (IH)");
      $self->devel("$name invalidated home due to serious wound");
    }
    else {  # roll == 6
      # Wounds fatal - mark as DOW (Died of Wounds)
      $member->set_disposition('DOW');
      $game->buffer_error("$name: Survival roll $roll - Wounds fatal, died of wounds (DOW)");
      $self->devel("$name died of wounds");
    }

    $processed_count++;
  }

  if ($processed_count > 0) {
    $self->devel("Processed $processed_count serious wound(s)");
  }

  return $processed_count;
}

__PACKAGE__->meta->make_immutable;
1;