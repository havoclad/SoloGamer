package SoloGamer::OnlyIfRollTable;
use v5.20;

use List::Util qw / max min /;
use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;

extends 'SoloGamer::RollTable';

has 'variable_to_test' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  builder      => '_build_variable_to_test',
);

has 'test_criteria' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  builder      => '_build_test_criteria',
);

has 'fail_message' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  builder      => '_build_fail_message',
);

has 'test_against' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  builder      => '_build_test_against',
);

sub _build_fail_message {
  my $self = shift;

  my $fail_message = $self->{'data'}->{'fail_message'};
  delete $self->{'data'}->{'fail_message'};
  return $fail_message;
}

sub _build_variable {
  my $self = shift;

  my $variable = $self->{'data'}->{'variable'};
  delete $self->{'data'}->{'variable'};
  return $variable;
}

sub _build_test_criteria {
  my $self = shift;
  
  my $test_criteria = $self->{'data'}->{'test_criteria'};
  delete $self->{'data'}->{'test_criteria'};
  return $test_criteria;
}

sub _build_variable_to_test {
  my $self = shift;
  
  my $variable_to_test = $self->{'data'}->{'variable_to_test'};
  delete $self->{'data'}->{'variable_to_test'};
  return $variable_to_test;
}

sub _build_test_against {
  my $self = shift;
  
  my $test_against = $self->{'data'}->{'test_against'};
  delete $self->{'data'}->{'test_against'};
  return $test_against;
}

override 'roll' => sub  {
  my $self     = shift;
  my $scope_in = shift;

  my $save = SoloGamer::SaveGame->instance;
  my $to_test = $save->get_from_current_mission($self->variable_to_test) || 0;
  my $test_criteria = $self->test_criteria;
  $self->devel("In OnlyIf with testing $to_test and test $test_criteria");
  if ( $test_criteria eq '>' ) {
    unless ( $to_test > $self->test_against ) {
      $self->devel($self->fail_message);
      return
    }
    $self->devel("OnlyIf test passed");
  } else {
    $self->devel("Don't know how to do a test_criteria of $test_criteria");
    return;
  }
  super();
};

__PACKAGE__->meta->make_immutable;
1;
