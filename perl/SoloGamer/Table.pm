package SoloGamer::Table;
use v5.10;

use File::Slurp;
use File::Basename;
use Mojo::JSON qw(decode_json encode_json);
use Moose;
use namespace::autoclean;

extends 'SoloGamer::Base';

sub __load_table {
  my $self = shift;

  my $f = read_file($self->file);
  my $p = decode_json($f);

  return $p;
}

sub __name {
  my $self = shift;

  return basename($self->file, ".json");
}

sub __title {
  my $self = shift;

  my $title = $self->{data}->{'Title'};
  delete $self->{data}->{'Title'};
  return $title;
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

has 'name' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  required => 1,
  builder  => '__name',
);

has 'title' => (
  is       =>'ro',
  isa      => 'Str',
  required => 1,
  lazy     => 1,
  builder  => '__title',
);

__PACKAGE__->meta->make_immutable;
1;
