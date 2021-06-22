package SoloGamer::Game;

use strict;
use v5.20;

use File::Basename;

use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;
use SoloGamer::TableFactory;

use Data::Dumper;

extends 'SoloGamer::Base';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'save'      => (
  is            => 'ro',
  #isa           => 'HashRef',
  builder       => '__save',
  lazy          => 1,
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

has 'automated' => (
  is       => 'ro',
  isa      => 'Int',
  init_arg => 'automated',
);

has 'zone' => (
  is       => 'rw',
  isa      => 'Str',
  init_arg => 1,
);

sub __save {
  my $self = shift;
  
  my $save = SoloGamer::SaveGame->initialize( save_file => $self->save_file,
                                              verbose   => $self->{'verbose'},
                                            );
  $save->load_save;
  return $save;
}

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
  my $factory = new SoloGamer::TableFactory(
                                            verbose   => $self->verbose,
                                            automated => $self->automated,
                                           );
  foreach my $table (<$dir/*>) {
    $self->devel("loading $table");
    my ($filename, $dirs, $suffix) = fileparse($table, qr/\.[^.]*/);
    $h->{$filename} = $factory->new_table( $table);
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
  my $reverse    = shift; # normal is low to high numerically

  my $path = "";
  my @keys;
  if ($reverse) { # Travelling home
    @keys = sort { $b <=> $a } keys $hr->%*;
    $path = "i";
  } else {        # Outboung
    @keys = sort { $a <=> $b } keys $hr->%*;
    $path = "o";
  }

  foreach my $i (@keys) {
    say $action, $i;
    $self->zone("$i$path");
  }
  return;
}

sub handle_output{
  my $self = shift;
  my $output = shift;
  my $key = shift;
  my $value = shift;
  my $text = shift || "";

  $self->devel("In handle output with key: $key, value: $value, and text: $text --");
  $self->save->add_save($key, $value);
  if ($text) {
    my $sss = $value == 1 ? '' : 's';
    $text =~ s/\(s\)/$sss/;
    $text =~ s/<1>/$value/;
    push $output->@*, $text;
  } else {
    push $output->@*, "$key: $value";
  }
}

sub do_roll {
  my $self  = shift;
  my $table = shift;

  my $roll = $self->tables->{$table}->roll($self->zone);
  if (defined $roll and exists $roll->{'notes'}) {
    foreach my $note ($roll->{'notes'}->@*) {
      my $modifier  = $note->{'modifier'};
      my $mod_table = $note->{'table'};
      my $why       = $note->{'why'};
      my $scope     = $note->{'scope'} || 'global';
      my $stack     = $note->{'stack'} || 1;

      if ($scope eq 'zone' ) {
        $scope = $self->zone;
      };
      $self->devel("$why results in a $modifier to table $mod_table for scope: $scope");

      exists $self->tables->{$mod_table} 
        and $self->tables->{$mod_table}->add_modifier($modifier, $why, $table, $scope, $stack);
    }
  }
  return $roll;
}

sub do_flow {
  my $self = shift;
  my $table_name = shift;

  my $output = ();
  my $table = $self->tables->{$table_name};
  while (my $next_flow = $table->get_next) {
    my $post = "";
    if (exists $next_flow->{'post'}) {
      $post = $next_flow->{'post'};
    }
    if (exists $next_flow->{'pre'}) {
      push $output->@*, $next_flow->{'pre'};
    }
    if (exists $next_flow->{'type'}) {
      if ($next_flow->{'type'} eq 'choosemax') {
        $self->save->add_save('Mission', $self->save->mission);
        my $choice = $next_flow->{'variable'};
        my $table = $self->do_max($self->save->get_from_current_mission($choice), $next_flow->{'choices'});
        my $roll = $self->do_roll($table);
        $self->handle_output($output, 'Target', $roll->{'Target'});
        $self->handle_output($output, 'Type', $roll->{'Type'});
      } elsif ($next_flow->{'type'} eq 'table') {
        my $table = $next_flow->{'Table'};
        my $roll = $self->do_roll($table);
        next unless defined $roll;
        my $determines = $self->tables->{$table}->determines;
        $self->handle_output($output, $determines, $roll->{$determines}, $post);
      } elsif ($next_flow->{'type'} eq 'loop') {
        my $loop_table = $next_flow->{'loop_table'};
        my $loop_variable = $next_flow->{'loop_variable'};
        my $reverse = exists $next_flow->{'reverse'} ? 1 : 0;
        my $target_city = $self->save->get_from_current_mission('Target');
        $self->do_loop( $self->tables->{$loop_table}->{'data'}->{'target city'}->{$target_city}->{$loop_variable},
                        "Moving to zone: ",
                        $reverse,
                      );
      } elsif ($next_flow->{'type'} eq 'flow') {
        my $flow_table = $next_flow->{'flow_table'};
        push $output->@*, $self->do_flow($flow_table)->@*;
      } else {
        die "Unknown flow type: ", $next_flow->{'type'};
      }
    }
    $self->devel("\nEnd flow step\n");
  }
  return $output;
}

sub run_game {
  my $self = shift;

  $self->devel("In run_game");
  my $mission = $self->save->mission;
  my $max_missions = $self->tables->{'FLOW-start'}->{'data'}->{'missions'};
  $mission == $max_missions and die "25 successful missions, your crew went home!";

  say foreach $self->do_flow('FLOW-start')->@*;

  $self->save->save_game;
}
__PACKAGE__->meta->make_immutable;
