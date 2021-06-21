FROM perl

RUN cpanm install Mojo::JSON File::Slurp Moose namespace::autoclean MooseX::Singleton
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
ENTRYPOINT ["/perl/SoloGamer.pl"]
