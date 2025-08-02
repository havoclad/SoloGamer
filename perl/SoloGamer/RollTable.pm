package SoloGamer::RollTable;
use v5.20;

use List::Util qw / max min sum /;
use Carp;

use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;

extends 'SoloGamer::Table';

has 'rolls' => (
  is       => 'ro',
  isa      => 'HashRef',
  builder  => '_build_rolls',
);

has 'scope' => (
  is       => 'rw',
  isa      => 'Str',
  lazy     => 1,
  builder  => '_build_scope',
);

has 'rolltype' => (
  is       => 'rw',
  isa      => 'Str',
  init_arg => 'rolltype',
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
  init_arg => 'determines',
);

has 'group_by' => (
  is              => 'ro',
  isa             => 'Str',
  init_arg        => 'group_by',
  default         => 'join',
);

has 'table_skip' => (
  is              => 'ro',
  isa             => 'Str',
  builder         => '_build_table_skip',
);

has 'table_count' => (
  is              => 'ro',
  isa             => 'Str',
  lazy            => 1,
  builder         => '_build_table_count',
);

has 'table_input' => (
  is              => 'ro',
  isa             => 'Str',
  builder         => '_build_table_input',
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

sub _build_table_skip {
  my $self = shift;

  my $table_skip = $self->data->{'table_skip'} || '';
  delete $self->data->{'table_skip'};
  return $table_skip;
}

sub _build_table_count {
  my $self = shift;

  my $table_count = 1;
  if ( exists $self->data->{'table_count'} ) {
    if ( $self->data->{'table_count'} =~ /^(\d+)$/ ) {
      $table_count = $1;
    } else { # Not a number? Must be a current mission variable
      my $save = SoloGamer::SaveGame->instance;
      $table_count = $save->get_from_current_mission($self->data->{'table_count'});
    }
    delete $self->data->{'table_count'};
  }
  return $table_count;
}

sub _build_table_input {
  my $self = shift;

  my $table_input = $self->data->{'table_input'} || '';
  delete $self->data->{'table_input'};
  return $table_input;
}

sub _build_scope {
  my $self = shift;

  my $scope = $self->data->{'scope'} || 'global';
  delete $self->data->{'scope'};
  return $scope;
}

sub _build_rolls {
  my $self = shift;

  my $hr = {};
  foreach my $key (keys $self->data->{rolls}->%*) {
    my $value = $self->data->{'rolls'}->{$key};
    if ($key =~ /^(\d+)-(\d+)$/) {    # example 3-11
      my $min = $1;
      my $max = $2;
      $max > $min or croak "Malformed range key $key";
      foreach my $n ($min .. $max) {
        $hr->{$n} = $value;
      }
    } elsif ( $key =~/^(\d+,)+\d+$/ ) {  # example 2,3
      foreach my $n (split ',', $key) {
        $hr->{$n} = $value;
      }
    } else {
      $hr->{$key} = $value;
    }
  }
  delete $self->data->{rolls};
  $self->set_max_min($hr);
  return $hr;
}

sub get_raw_result {
  my $self = shift;

  my $result = '';
  $self->devel("Roll Type is: ", $self->rolltype);
  if ($self->rolltype =~ /^(\d+)d(\d+)$/) {
    my $num_rolls = $1;
    my $die_size  = $2;
    my $int_result = 0;
    foreach my $n (1 .. $num_rolls) {
      $int_result += int(rand($die_size)+1);
    }
    $result = $int_result;
  } elsif ($self->rolltype =~ /^(d\d+)+$/) {
    my @dice = split /d/, $self->rolltype;
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
      return if $table_input eq $self->table_skip;
    }
  }
  $self->devel("Rolling ", $self->table_count, " times on table: ", $self->name, " for scope $scope_in");
  my $total_modifiers = $self->get_total_modifiers($scope_in);
  my $accumulator_array = [];
  for (1 .. $self->table_count) {
    my $result = $self->get_raw_result;
    $result += $total_modifiers;
    $result = min ($result, $self->max_roll);  # don't fall off the table
    $result = max ($result, $self->min_roll);
    if ($table_input) {
      $self->devel("Rolled a $result on table " . $self->name . " " .  $self->title , " with table-input: ", $table_input);
      if ($self->table_count>1) {
        push $accumulator_array->@*, $self->rolls->{$result}->{$table_input}->{$self->determines};
      } else {
        return { $self->rolls->{$result}->{$table_input}->%* };
      }
    } else {
      $self->devel("Rolled a $result on table " . $self->name . " " .  $self->title);
      if ($self->table_count>1) {
        push $accumulator_array->@*, $self->rolls->{$result}->{$self->determines};
      } else {
        return { $self->rolls->{$result}->%* };
      }
    }
  }
  my $accumulator;
  if ( $self->group_by eq 'sum' ) {
    $accumulator = sum $accumulator_array->@*;
  } else {
    $accumulator = join ', ', $accumulator_array->@*;
  }
  return { $self->determines => $accumulator };
}

sub set_max_min {
  my $self = shift;
  my $hr   = shift;

  return unless keys $hr->%* > 1;
  my @keys = keys $hr->%*;
  foreach my $key (@keys) {
    return unless $key =~ /^-?\d+$/;
  }
  my $min = min(@keys);
  $self->min_roll($min);
  my $max = max(@keys);
  $self->max_roll($max);
  return;
}

sub add_modifier {
  my $self       = shift;
  my $arg_ref    = shift;

  if ($arg_ref->{stack} == 0) {
    foreach my $note ( $self->{'modifiers'}->@* ) {
      if (        $arg_ref->{modifier} eq $note->{'modifier'} 
            and ( $arg_ref->{why} eq $note->{'why'} )
            and ( $arg_ref->{from_table} eq $note->{'from_table'} )
            and ( $arg_ref->{scope} eq $note->{'scope'} ) ) {
        $self->devel("Not stacking modifier on table ", $self->name);
        return;
      }
    }
  }
  push $self->{'modifiers'}->@*, {
                                   why        => $arg_ref->{why},
                                   modifier   => $arg_ref->{modifier},
                                   from_table => $arg_ref->{from_table},
                                   scope      => $arg_ref->{scope},
                                 };
  return;
}
__PACKAGE__->meta->make_immutable;
1;
