package SoloGamer::Game;

use strict;
use v5.20;

use File::Basename;
use Carp;

use Moose;
use namespace::autoclean;

use SoloGamer::SaveGame;
use SoloGamer::TableFactory;

extends 'SoloGamer::Base';

with 'BufferedOutput';

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'save'      => (
  is            => 'ro',
  #isa           => 'HashRef',
  builder       => '_build_save',
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
  builder  => '_build_load_data_tables',
);

has 'automated' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'automated',
);

has 'zone' => (
  is       => 'rw',
  isa      => 'Str',,
  init_arg => 1,
);

sub _build_save {
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

sub _build_load_data_tables {
  my $self = shift;

  my $h = {};
  my $dir = $self->source_data;
  $self->devel("looking for $dir");
  my $factory = SoloGamer::TableFactory-> new (
                                            verbose   => $self->verbose,
                                            automated => $self->automated,
                                           );
  foreach my $table (glob("$dir/*")) {
    $self->devel("loading $table");
    my ($filename, $dirs, $suffix) = fileparse($table, '.json');
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
  croak "Didn't find a max that matched $variable";
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
    $self->buffer( "$action $i");
    $self->zone("$i$path");
  }
  return;
}

sub handle_output{
  my $self = shift;
  my $key = shift;
  my $value = shift;
  my $text = shift;

  $self->save->add_save($key, $value);
  if ( defined $text and length $text ) {
    $self->devel("In handle output with key: $key, value: $value, and text: $text --");
    $text =~ s{ <1>   }{ $value }xmse;
    $text =~ s{ \(s\) }{ $value == 1? '' : 's'}xmse;
    $self->buffer($text);
  } else {
    $self->devel("In handle output with key: $key, value: $value");
    $self->buffer("$key: $value");
  }
  return;
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
        and $self->tables->{$mod_table}->add_modifier( { modifier => $modifier,
                                                         why      => $why, 
                                                         from_table    => $table,
                                                         scope    => $scope,
                                                         stack    => $stack
                                                       } );
    }
  }
  return $roll;
}

sub do_flow {
  my $self = shift;
  my $table_name = shift;

  while (my $next_flow = $self->tables->{$table_name}->get_next) {
    my $buffer_save = $self->get_buffer_size;
    my $post = "";
    if (exists $next_flow->{'post'}) {
      $post = $next_flow->{'post'};
    }
    if (exists $next_flow->{'pre'}) {
      $self->buffer($next_flow->{'pre'});
    }
    if (exists $next_flow->{'type'}) {
      if ($next_flow->{'type'} eq 'choosemax') {
        $self->save->add_save('Mission', $self->save->mission);
        my $choice = $next_flow->{'variable'};
        my $table = $self->do_max($self->save->get_from_current_mission($choice), $next_flow->{'choices'});
        my $roll = $self->do_roll($table);
        $self->handle_output('Target', $roll->{'Target'});
        $self->handle_output('Type', $roll->{'Type'});
      } elsif ($next_flow->{'type'} eq 'table') {
        my $table = $next_flow->{'Table'};
        my $roll = $self->do_roll($table);
        if (not defined $roll) {
          $self->flush_to($buffer_save);
          next;
        }
        my $determines = $self->tables->{$table}->determines;
        $self->handle_output($determines, $roll->{$determines}, $post);
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
        $self->do_flow($flow_table);
      } else {
        croak "Unknown flow type: ", $next_flow->{'type'};
      }
    }
    $self->devel("\nEnd flow step\n");
  }
  $self->print_output;
  return;
}

sub run_game {
  my $self = shift;

  $self->devel("In run_game");
  my $mission = $self->save->mission;
  my $max_missions = $self->tables->{'FLOW-start'}->{'data'}->{'missions'};
  $mission == $max_missions and croak "25 successful missions, your crew went home!";

  $self->do_flow('FLOW-start');

  $self->save->save_game;
  return;
}
__PACKAGE__->meta->make_immutable;
1;
