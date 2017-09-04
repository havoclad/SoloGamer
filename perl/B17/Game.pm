package B17::Game;

use strict;

use Moose;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
 
    if ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( name => $_[0] );
    }
    else {
        return $class->$orig(@_);
    }
};

sub BUILD {
  my $self = shift;
  my $args = shift;

  exists $args->{name} and $self->name($args->{name});
}

has 'name' => (
  is  => 'rw',
  isa => 'Str',
);
#sub new {
#  my $game = $ENV{'GAME'};
#  die "No game specified, use -e" unless $game;
#}

no Moose;
__PACKAGE__->meta->make_immutable;
