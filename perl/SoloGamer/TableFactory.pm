package SoloGamer::TableFactory;

use v5.42;

use File::Slurp;
use File::Basename;
use Carp;

use Mojo::JSON qw(decode_json encode_json);
use Moose;
use namespace::autoclean;

use SoloGamer::FlowTable;
use SoloGamer::RollTable;
use SoloGamer::OnlyIfRollTable;

extends 'SoloGamer::Base';

has 'automated'  => (
  is             => 'ro',
  isa            => 'Int',
  init_arg       => 'automated',
  default        => 0,
  lazy           => 1,
);

sub load_json_file ($self, $filename) {

  my $f = read_file($filename);
  my $p = decode_json($f);

  return $p;
}

sub new_table ($self, $filename) {

  my $json = $self->load_json_file($filename);
  my $h;
  $self->devel("loading $filename");
  my ($name, $path, $suffix) = fileparse ($filename, '.json');
  my %arguments = ( file => $filename, 
                    verbose => $self->verbose,
                    automated => $self->automated,
                    name    => $name,
                  );
  foreach my $term ( qw / group_by rolltype determines variable_to_test
                          Title test_criteria test_against fail_message / ) {
    if (exists $json->{$term}) {
      $arguments{$term} = $json->{$term};
      delete $json->{$term};
    }
  }
  my $table_type = $json->{table_type};
  delete $json->{table_type};
  $arguments{data} = $json;
  SWITCH: {
    for ($table_type ) {
      if (/^Flow/xms)   { $h = SoloGamer::FlowTable->new( %arguments ); last SWITCH; }
      if (/^roll/xms)   { $h = SoloGamer::RollTable->new( %arguments ); last SWITCH; }
      if (/^onlyif/xms) { $h = SoloGamer::OnlyIfRollTable->new( %arguments ); last SWITCH; }
      { croak "table_type of $table_type found in $filename" }
    }
  }
  return $h;
}

__PACKAGE__->meta->make_immutable;
1;
