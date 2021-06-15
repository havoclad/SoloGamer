package SoloGamer::RollTable;
use v5.20;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Table';

sub roll {
  my $self = shift;

  $self->devel("Rolling on table: ", $self->name);
  my $total_modifiers = 0;
  if ($self->{'modifiers'}->$#*) {
    foreach my $note ($self->{'modifiers'}->@*) {
      my $modifier      = $note->{'modifier'};
      my $from_table    = $note->{'from_table'};
      my $why           = $note->{'why'};

      $self->devel("Applying $modifier from table $from_table because $why");
      $total_modifiers += $modifier;
    }
  }
  $self->devel("Total modifiers: $total_modifiers");


  $self->devel("Roll Type is: ", $self->roll_type);
  my $result = "";
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
  $self->devel("Rolled a $result on table " . $self->name . " " .  $self->title);
  return { $self->rolls->{$result}->%* };
}

sub __roll_type {
  my $self = shift;

  my $roll_type = $self->data->{'rolltype'};
  delete $self->data->{'rolltype'};
  return $roll_type;
}

sub __determines {
  my $self = shift;

  my $determines = $self->data->{'determines'};
  delete $self->data->{'determines'};
  return $determines;
}

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

has 'automated' => (
  is       => 'ro',
  isa      => 'Int',
  init_arg => 'automated',
);

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
  return $hr;
}

has 'rolls' => (
  is       => 'ro',
  isa      => 'HashRef',
  builder  => '__rolls',
);

sub add_modifier {
  my $self       = shift;
  my $modifier   = shift;
  my $why        = shift;
  my $from_table = shift;

  push $self->{'modifiers'}->@*, {
                                   why        => $why,
                                   modifier   => $modifier,
                                   from_table => $from_table,
                                 };
}
__PACKAGE__->meta->make_immutable;
1;
