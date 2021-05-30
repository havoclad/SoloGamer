package SoloGamer::Game;

use strict;
use v5.10;

use File::Basename;

use Moose;
use namespace::autoclean;

use SoloGamer::LoadTable;

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

sub _build_source_data {
  my $self = shift;
  return $self->source . 'data';
}

sub _load_data_tables {
  my $self = shift;

  my $h = {};
  my $dir = $self->source_data;
  say "looking for $dir";
  foreach my $table (<$dir/*>) {
	  say "loading $table";
    my ($filename, $dirs, $suffix) = fileparse($table, qr/\.[^.]*/);
    $h->{$filename} = new SoloGamer::LoadTable( file => $table );
  }
  return $h;
}

sub run_game {
  my $self = shift;

  say "Rolling for Mission";

}
__PACKAGE__->meta->make_immutable;
