package B17::LoadTable;

use strict;
use Data::Dumper;

use File::Slurp;
use Mojo::JSON qw(decode_json encode_json);
use Moose;
use namespace::autoclean;

sub __load_table {
  my $self = shift;

  my $f = read_file($self->file);
  my $p = decode_json($f);

  return $p;
}

sub __roll {
  my $self = shift;

  my $d = $self->data;
  return (keys %$d)[rand keys %$d];
}

has 'data' => (
 is       => 'ro',
 isa      => 'HashRef',
 lazy     => 1,
 builder  => '__load_table',
 required => 1,
);

has 'file' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'file',
);

has 'roll' => (
  is       => 'rw',
  isa      => 'Int',
  builder  => '__roll',
);

__PACKAGE__->meta->make_immutable;
1;
