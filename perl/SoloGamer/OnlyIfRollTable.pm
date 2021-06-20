package SoloGamer::OnlyIfRollTable;
use v5.20;

use List::Util qw / max min /;
use Moose;
use namespace::autoclean;

use Data::Dumper;

extends 'SoloGamer::RollTable';

has 'variable' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  builder      => '__variable',
);

sub __variable {
  my $self = shift;

  my $variable = $self->{'data'}->{'variable'};
  delete $self->{'data'}->{'variable'};
  return $variable;
}

has 'test'      => (
  is            => 'ro',
  isa           => 'Str',
  required      => 1,
  builder       => '__test',
);

sub __test {
  my $self = shift;
  
  my $test = $self->{'data'}->{'test'};
  delete $self->{'data'}->{'test'};
  return $test;
}

override 'roll' => sub  {
  my $self     = shift;
  my $scope_in = shift;
  my $mission  = shift;

  $self->variable eq 'mission' or die "OnlyIf can only handle mission variables";
  my $test = $self->test;
  $self->devel("In OnlyIf with mission: $mission and test $test");
  if (eval "$mission $test") {
    $self->devel("OnlyIf test passed");
    super();
  } else {
    $self->devel("Nothing to do in OnlyIf");
    return undef;
  }
};

__PACKAGE__->meta->make_immutable;
1;
