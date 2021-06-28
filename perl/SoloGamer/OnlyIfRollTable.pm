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
  init_arg     => 'variable_to_test',
);

has 'test_criteria' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  init_arg     => 'test_criteria',
);

has 'fail_message' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  init_arg     => 'fail_message',
);

has 'test_against' => (
  is           => 'ro',
  isa          => 'Str',
  required     => 1,
  init_arg     => 'test_against',
);

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
