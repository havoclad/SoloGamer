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

sub __rolls {
  my $self = shift;

  my $hr = {};
  foreach my $key (keys $self->data->{rolls}->%*) {
    if ($key =~ /^(\d+)-(\d+)$/) {
      my $min = $1;
      my $max = $2;
      $max > $min or die "Malformed range key $key";
      foreach my $n ($min .. $max) {
        $hr->{$n} = $self->data->{rolls}->{$key};
      }
    } else {
      $hr->{$key} = $self->data->{rolls}->{$key};
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
