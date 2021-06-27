package SoloGamer::Table;
use v5.10;

use Moose;
use namespace::autoclean;

extends 'SoloGamer::Base';

sub _build_pre {
  my $self = shift;

  my $pre = $self->{data}->{'pre'} || '';
  delete $self->{data}->{'pre'};
  return $pre;
}

sub _build_title {
  my $self = shift;

  my $title = $self->{data}->{'Title'};
  delete $self->{data}->{'Title'};
  return $title;
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
  lazy     => 1,
  builder  => '_build_title',
);

__PACKAGE__->meta->make_immutable;
1;
