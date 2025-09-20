package SoloGamer::Table;
use v5.42;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Base';

sub _build_pre {
  my $self = shift;

  my $pre = $self->{data}->{pre} || '';
  delete $self->{data}->{pre};
  return $pre;
}

has 'data' => (
 is       => 'ro',
 isa      => 'HashRef',
 init_arg => 'data',
 required => 1,
);

has 'file' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'file',
);

has 'pre' => (
  is       => 'ro',
  isa      => 'Str',
  builder  => '_build_pre',
);

has 'name' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'name',
);

has 'title' => (
  is       =>'ro',
  isa      => 'Str',
  required => 1,
  init_arg => 'Title',
);

__PACKAGE__->meta->make_immutable;
1;
