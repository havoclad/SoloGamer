FROM perl

RUN cpanm install Mojo::JSON File::Slurp Moose namespace::autoclean MooseX::Singleton Term::ANSIColor
RUN cpanm Perl::Critic
RUN cpanm MooseX::Types
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
ENTRYPOINT ["/perl/SoloGamer.pl"]
