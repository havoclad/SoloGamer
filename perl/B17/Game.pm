package B17::Game;

use strict;

use File::Basename;

use Moose;
use namespace::autoclean;

use B17::LoadTable;

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
  return $self->source . 'data/';
}

sub _load_data_tables {
  my $self = shift;

  my $h = {};
  my $dir = $self->source_data;
  foreach my $table (<$dir/*>) {
    my ($filename, $dirs, $suffix) = fileparse($table, qr/\.[^.]*/);
    $h->{$filename} = new B17::LoadTable( file => $table );
  }
  return $h;
}

__PACKAGE__->meta->make_immutable;
