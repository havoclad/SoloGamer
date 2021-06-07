package SoloGamer::Game;

use strict;
use v5.20;

use File::Basename;

use Moose;
use namespace::autoclean;

use SoloGamer::FlowTable;
use SoloGamer::RollTable;
use SoloGamer::SaveGame;

use Data::Dumper;

extends 'SoloGamer::Base';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'mission' => (
  is       => 'rw',
  isa      => 'Int',
);

has 'name' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'name',
);

has 'source_data' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  required => 1,
  builder  => '_build_source_data',
);

has 'source' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  required => 1,
  builder  => '_build_source',
);

has 'tables' => (
  is       => 'ro',
  isa      => 'HashRef',
  lazy     => 1,
  required => 1,
  builder  => '_load_data_tables',
);

sub _build_source {
  my $self = shift;
  return '/games/' . $self->name . '/';
}

sub _build_source_data {
  my $self = shift;
  return $self->source . 'data';
}

sub _load_data_tables {
  my $self = shift;

  my $h = {};
  my $dir = $self->source_data;
  $self->devel("looking for $dir");
  foreach my $table (<$dir/*>) {
    $self->devel("loading $table");
    my ($filename, $dirs, $suffix) = fileparse($table, qr/\.[^.]*/);
    if ($filename eq 'start') {
      $h->{$filename} = new SoloGamer::FlowTable( file => $table,
                                                  verbose => $self->verbose
                                                );
    } else {
      $h->{$filename} = new SoloGamer::RollTable( file => $table,
                                                  verbose => $self->verbose
                                                );
    }
  }
  return $h;
}

# Intent is to return the first item in an array that is less than the input
sub do_max {
  my $self = shift;
  my $variable = shift;
  my $choices = shift;

  foreach my $item (@$choices) {
    return $item->{'Table'} if $variable <= $item->{'max'};
  }
  die "Didn't find a max that matched $variable";
}

sub run_game {
  my $self = shift;

  $self->devel("In run_game");
  my $save = new SoloGamer::SaveGame( save_file => $self->save_file);
  my $mission = $save->load_save;
  $self->mission($mission);

  while (my $next_flow = $self->tables->{'start'}->get_next) {
    say $next_flow->{'pre'};
    if (exists $next_flow->{'type'}) {
      my $post = $next_flow->{'post'};
      my $output = "";
      if ($next_flow->{'type'} eq 'choosemax') {
        my $choice = $next_flow->{'variable'};
        my $table = $self->do_max($self->{$choice}, $next_flow->{'choices'});
        $table eq 'end' and die "25 successful missions, your crew went home!";
        my $roll = $self->tables->{$table}->roll;
        $output = $roll->{'Target'} . " it's a " . $roll->{'Type'};
        $save->add_save('Mission', $self->mission);
        $save->add_save('Target', $roll->{'Target'});
        $save->add_save('Type', $roll->{'Type'});
      } elsif ($next_flow->{'type'} eq 'table') {
        my $table = $next_flow->{'Table'};
        my $roll = $self->tables->{$table}->roll;
        my $determines = $self->tables->{$table}->determines;
        $output = $roll->{$determines};
        $save->add_save($determines, $output);
      }
      $post =~ s/<1>/$output/;
      say $post;
    }
  }

  $save->save_game;
}
__PACKAGE__->meta->make_immutable;
