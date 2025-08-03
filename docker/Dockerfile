FROM perl

RUN cpanm install Mojo::JSON File::Slurp Moose namespace::autoclean MooseX::Singleton Term::ANSIColor
RUN cpanm Perl::Critic
RUN cpanm MooseX::Types
RUN cpanm Test::Class::Moose Test2::Suite Test::MockObject File::Temp Devel::Cover Test::Exception
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
ENTRYPOINT ["/perl/SoloGamer.pl"]
