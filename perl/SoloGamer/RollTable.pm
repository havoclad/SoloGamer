package SoloGamer::RollTable;
use v5.20;

use List::Util qw / max min /;
use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;

use Data::Dumper;

extends 'SoloGamer::Table';

has 'rolls' => (
  is       => 'ro',
  isa      => 'HashRef',
  builder  => '__rolls',
);

has 'scope' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '__scope',
);

has 'roll_type' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '__roll_type',
);

has 'modifiers' => (
  is       =>'ro',
  isa      =>'ArrayRef',
  lazy     => 1,
  default  => sub { [] },
);

has 'determines' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  builder  => '__determines',
);

has 'table_skip' => (
  is              => 'ro',
  isa             => 'Str',
  builder         => '_table_skip',
);

has 'table_count' => (
  is              => 'ro',
  isa             => 'Int',
  builder         => '_table_count',
);

has 'table_input' => (
  is              => 'ro',
  isa             => 'Str',
  builder         => '_table_input',
);

has 'automated' => (
  is       => 'ro',
  isa      => 'Int',
  init_arg => 'automated',
);

has 'max_roll' => (
  is       => 'rw',
  isa      => 'Int',
  lazy     => 1,
  default  => 0,
);

has 'min_roll' => (
  is       => 'rw',
  isa      => 'Int',
  lazy     => 1,
  default  => 100,
);

sub _table_skip {
  my $self = shift;

  my $table_skip = $self->data->{'table_skip'} || '';
  delete $self->data->{'table_skip'};
  return $table_skip;
}

sub _table_count {
  my $self = shift;

  my $table_count = $self->data->{'table_count'} || 1;
  delete $self->data->{'table_count'};
  return $table_count;
}

sub _table_input {
  my $self = shift;

  my $table_input = $self->data->{'table_input'} || '';
  delete $self->data->{'table_input'};
  return $table_input;
}

sub __roll_type {
  my $self = shift;

  my $roll_type = $self->data->{'rolltype'};
  delete $self->data->{'rolltype'};
  return $roll_type;
}

sub __scope {
  my $self = shift;

  my $scope = $self->data->{'scope'} || 'global';
  delete $self->data->{'scope'};
  return $scope;
}

sub __determines {
  my $self = shift;

  my $determines = $self->data->{'determines'};
  delete $self->data->{'determines'};
  return $determines;
}

sub __rolls {
  my $self = shift;

  my $hr = {};
  foreach my $key (keys $self->data->{rolls}->%*) {
    my $value = $self->data->{'rolls'}->{$key};
    if ($key =~ /^(\d+)-(\d+)$/) {    # example 3-11
      my $min = $1;
      my $max = $2;
      $max > $min or die "Malformed range key $key";
      foreach my $n ($min .. $max) {
        $self->check_max_min($n);
        $hr->{$n} = $value;
      }
    } elsif ( $key =~/^(\d+,)+\d+$/ ) {  # example 2,3
      foreach my $n (split ',', $key) {
        $self->check_max_min($n);
        $hr->{$n} = $value;
      }
    } else {
      $self->check_max_min($key);
      $hr->{$key} = $value;
    }
  }
  delete $self->data->{rolls};
  return $hr;
}

sub get_raw_result {
  my $self = shift;

  my $result = '';
  $self->devel("Roll Type is: ", $self->roll_type);
  if ($self->roll_type =~ /^(\d+)d(\d+)$/) {
    my $num_rolls = $1;
    my $die_size  = $2;
    my $int_result = 0;
    foreach my $n (1 .. $num_rolls) {
      $int_result += int(rand($die_size)+1);
    }
    $result = $int_result;
  } elsif ($self->roll_type =~ /^(d\d+)+$/) {
    my @dice = split /d/, $self->roll_type;
    shift @dice;
    foreach my $die (@dice) {
      $self->devel("Rolling a die with $die sides");
      $result .= int(rand($die)+1);
    }
  }
  return $result;
}

sub get_total_modifiers {
  my $self     = shift;
  my $scope_in = shift;

  my $total_modifiers = 0;
  foreach my $note ($self->{'modifiers'}->@*) {
    my $modifier      = $note->{'modifier'};
    my $from_table    = $note->{'from_table'};
    my $why           = $note->{'why'};
    my $scope         = $self->scope;
    next unless $scope eq 'global' or $scope eq $scope_in;

    $self->devel("Applying $modifier from table $from_table because $why");
    $total_modifiers += $modifier;
  }
  $self->devel("Total modifiers: $total_modifiers");
  return $total_modifiers;
}

sub roll {
  my $self     = shift;
  my $scope_in = shift || 'global';

  # first see if we have to skip this
  my $table_input = undef;
  if (length $self->table_input) {
    my $save = SoloGamer::SaveGame->instance;
    $table_input = $save->get_from_current_mission($self->table_input);
    if ( $table_input eq $self->table_skip ) {
      $self->devel("returning early to do a table_skip match of $table_input");
      return undef if $table_input eq $self->table_skip;
    }
  }
  $self->devel("Rolling on table: ", $self->name, " for scope $scope_in");
  my $total_modifiers = $self->get_total_modifiers($scope_in);
  my $result = $self->get_raw_result;
  $result += $total_modifiers;
  my $accumulator = 0;
  for (1 .. $self->table_count) {
    $result = min ($result, $self->max_roll);  # don't fall off the table
    $result = max ($result, $self->min_roll);
    if ($table_input) {
      $self->devel("Rolled a $result on table " . $self->name . " " .  $self->title , " with table-input: ", $table_input);
      if ($self->table_count>1) {
        $accumulator += $self->rolls->{$result}->{$table_input}->{$self->determines};
      } else {
        return { $self->rolls->{$result}->{$table_input}->%* };
      }
    } else {
      $self->devel("Rolled a $result on table " . $self->name . " " .  $self->title);
      return { $self->rolls->{$result}->%* };
    }
  }
  return { $self->determines => $accumulator };
}

sub check_max_min {
  my $self  = shift;
  my $check = shift;

  $self->min_roll($check) if $check < $self->min_roll;
  $self->max_roll($check) if $check > $self->max_roll;
};

sub add_modifier {
  my $self       = shift;
  my $modifier   = shift;
  my $why        = shift;
  my $from_table = shift;
  my $scope      = shift;

  push $self->{'modifiers'}->@*, {
                                   why        => $why,
                                   modifier   => $modifier,
                                   from_table => $from_table,
                                   scope      => $scope,
                                 };
}
__PACKAGE__->meta->make_immutable;
1;
