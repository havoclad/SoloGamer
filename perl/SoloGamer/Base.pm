package SoloGamer::Base;
use v5.42;

use Moose;
use namespace::autoclean;

with 'Logger';

__PACKAGE__->meta->make_immutable;
1;
