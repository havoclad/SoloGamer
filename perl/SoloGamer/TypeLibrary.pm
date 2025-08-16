package SoloGamer::TypeLibrary;

use v5.42;
 
# predeclare our own types
use MooseX::Types -declare => [
    qw(
        PositiveInt
        NegativeInt
        NonNegativeInt
        )
];
 
# import builtin types
use MooseX::Types::Moose qw/Int HashRef/;
 
# type definition.
subtype PositiveInt,
    as Int,
    where { $_ > 0 },
    message { "Int is not larger than 0" };
 
subtype NonNegativeInt,
    as Int,
    where { $_ > -1 },
    message { "Int is not 0 or higher" };
 
subtype NegativeInt,
    as Int,
    where { $_ < 0 },
    message { "Int is not smaller than 0" };
 
# type coercion
coerce PositiveInt,
    from Int,
        via { 1 };
 
1;
