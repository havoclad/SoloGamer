package SoloGamer::RollTable;
use v5.20;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Table';

sub __roll {
  my $self = shift;

  my $d = $self->rolls;

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
  return { $d->{$result}->%* };
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

has 'roll' => (
  is       => 'rw',
  isa      => 'HashRef',
  lazy     => 1,
  builder  => '__roll',
);

has 'determines' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  builder  => '__determines',
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
    } elsif ( $key =~/^(\d,)+\d$/ ) {  # example 2,3
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
__PACKAGE__->meta->make_immutable;
1;
