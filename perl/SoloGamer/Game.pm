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

sub do_loop {
  my $self       = shift;
  my $hr         = shift;  # Whatever hash we're looping on
  my $action     = shift;
  my $reverse    = shift || ""; # normal is low to high numerically

  print Dumper $hr;
  my @keys = $reverse
           ? sort { $b <=> $a } keys $hr->%*
           : sort { $a <=> $b } keys $hr->%*;

  print Dumper join " ", @keys;
  foreach my $i (@keys) {
    say $action, $i;
  }
  return;
}

sub run_game {
  my $self = shift;

  $self->devel("In run_game");
  my $save = new SoloGamer::SaveGame( save_file => $self->save_file,
                                      verbose   => $self->{'verbose'} || 0,
                                    );
  my $mission = $save->load_save;
  my $max_missions = $self->tables->{'start'}->{'data'}->{'missions'};
  $mission == $max_missions and die "25 successful missions, your crew went home!";

  while (my $next_flow = $self->tables->{'start'}->get_next) {
    if (exists $next_flow->{'type'}) {
      my $post = $next_flow->{'post'};
      my $output = "";
      if ($next_flow->{'type'} eq 'choosemax') {
        $save->add_save('Mission', $mission);
        my $choice = $next_flow->{'variable'};
        my $table = $self->do_max($save->get_from_current_mission($choice), $next_flow->{'choices'});
        my $roll = $self->tables->{$table}->roll;
        $output = $roll->{'Target'} . " it's a " . $roll->{'Type'};
        $save->add_save('Target', $roll->{'Target'});
        $save->add_save('Type', $roll->{'Type'});
      } elsif ($next_flow->{'type'} eq 'table') {
        my $table = $next_flow->{'Table'};
        my $roll = $self->tables->{$table}->roll;
        my $determines = $self->tables->{$table}->determines;
        $output = $roll->{$determines};
        $save->add_save($determines, $output);
      } elsif ($next_flow->{'type'} eq 'onlyif') {
        my $variable = $save->get_from_current_mission($next_flow->{'variable'});
        my $check = $next_flow->{'check'};
        $self->devel("Checking $variable to see if it matches $check");
        if ( eval "$variable $check" ) {
          my $table = $next_flow->{'Table'};
          my $roll = $self->tables->{$table}->roll;
          my $determines = $self->tables->{$table}->determines;
          $output = $roll->{$determines};
          $save->add_save($determines, $output);
        } else {
          $self->devel("Skipping as check didn't pass");
          next;
        }
      } elsif ($next_flow->{'type'} eq 'loop') {
        my $loop_table = $next_flow->{'loop_table'};
        my $loop_variable = $next_flow->{'loop_variable'};
        my $target_city = $save->get_from_current_mission('Target');
        $self->do_loop( $self->tables->{$loop_table}->{'data'}->{'target city'}->{$target_city}->{$loop_variable},
                        "Moving to zone: ",
                      );
      } else {
        die "Unknown flow type: ", $next_flow->{'type'};
      }
      say $next_flow->{'pre'};
      $post =~ s/<1>/$output/;
      say $post;
    }
    $self->devel("\nEnd flow step\n");
  }

  $save->save_game;
}
__PACKAGE__->meta->make_immutable;
