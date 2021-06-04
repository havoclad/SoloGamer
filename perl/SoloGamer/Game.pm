package SoloGamer::Game;

use strict;
use v5.20;

use File::Basename;
use File::Copy;
use File::Slurp;

use Moose;
use Mojo::JSON qw ( encode_json decode_json );
use namespace::autoclean;

use SoloGamer::FlowTable;
use SoloGamer::RollTable;

use Data::Dumper;

extends 'SoloGamer::Base';

has 'verbose' => (
  is       => 'ro',
  isa      => 'Int',
  init_arg => 'verbose',
  lazy     => 1,
  default  => 0,
);

has 'save_file' => (
  is            => 'ro',
  isa           => 'Str',
  init_arg      => 'save_file',
);

has 'save'    => (
  is          => 'rw',
  isa         => 'HashRef',
  lazy        => 1,
  default     => sub { {} },
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

has 'table' => (
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

sub devel {
  my $self = shift;

  $self->verbose or return;

  say @_;
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

sub load_save {
  my $self = shift;

  my $save_to_load = $self->save_file or return;

  if (-e $save_to_load) {
    $self->devel("Trying to load $save_to_load");
    open(my $fh, "<", $self->save_file) or die("Can't open: ", $self->save_file);
    my $json = read_file($fh);
    close $fh;
    $self->save(decode_json($json)) or die $!;
    my $last_mission = $self->save->{mission}->$#* + 1;
    $self->devel("Last mission was: $last_mission");
    $self->mission($last_mission+1);
  } else {
    $self->devel("No save file found at $save_to_load");
    $self->mission(1);
    my $temp = { mission => [{}] };
    $self->save($temp);
  }

}

sub save_game {
  my $self = shift;

  if ($self->save_file) {
    $self->devel("Writing save file to ", $self->save_file);
    my $tmp_file = $self->save_file . '.tmp';
    open(my $fh, ">", $tmp_file) or die "Can't open $tmp_file $!";
    print $fh encode_json($self->save) or die("Can't write file at: ", $tmp_file, " $!");
    close $fh;
    move($tmp_file, $self->save_file) or die("Can't move $tmp_file to ", $self->save_file);
  } else {
    $self->devel("No save file to write");
  }
}

sub run_game {
  my $self = shift;

  $self->load_save;

  while (my $next_flow = $self->table->{'start'}->get_next) {
    say $next_flow->{'pre'};
    if (exists $next_flow->{'Table'}) {
      $self->devel("Next is: ", $next_flow->{'Table'});
      my $post = $next_flow->{'post'};
      my $table = $next_flow->{'Table'};
      my $roll = $self->table->{$table}->roll;
      my $output = $roll->{'Target'} . " it's a " . $roll->{'Type'};
      $self->save->{'mission'}->[$self->mission-1]->{'Mission'} = $self->mission;
      $self->save->{'mission'}->[$self->mission-1]->{'Target'} = $roll->{'Target'};
      $self->save->{'mission'}->[$self->mission-1]->{'Type'} = $roll->{'Type'};
      $post =~ s/<1>/$output/;
      say $post;
    }
  }

  $self->save_game;
}
__PACKAGE__->meta->make_immutable;
