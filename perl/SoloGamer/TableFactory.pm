package SoloGamer::TableFactory;

use strict;
use v5.20;
use feature "switch";

use File::Slurp;
use File::Basename;

use Mojo::JSON qw(decode_json encode_json);
use Moose;
use namespace::autoclean;

use SoloGamer::FlowTable;
use SoloGamer::RollTable;
use SoloGamer::OnlyIfRollTable;

use Data::Dumper;

extends 'SoloGamer::Base';

has 'automated'  => (
  is             => 'ro',
  isa            => 'Int',
  init_arg       => 'automated',
  default        => 0,
  lazy           => 1,
);

sub load_json_file {
  my $self     = shift;
  my $filename = shift;

  my $f = read_file($filename);
  my $p = decode_json($f);

  return $p;
}

sub new_table {
  my $self     = shift;
  my $filename = shift;

  my $json = $self->load_json_file($filename);
  my $h;
  $self->devel("loading $filename");
  my ($name, $path, $suffix) = fileparse ($filename, '.json');
  my %arguments = ( file => $filename, 
                    verbose => $self->verbose,
                    automated => $self->automated,
                    data    => $json,
                    name    => $name,
                  );
  my $table_type = $json->{'table_type'};
  given ($table_type ) {
    when (/^Flow/)   { $h = SoloGamer::FlowTable->new( %arguments ); }
    when (/^roll/)   { $h = SoloGamer::RollTable->new( %arguments ); }
    when (/^onlyif/) { $h = SoloGamer::OnlyIfRollTable->new( %arguments ); }
    default        { die "table_type of $table_type found in $filename" }
  }
  return $h;
}

__PACKAGE__->meta->make_immutable;
1;
