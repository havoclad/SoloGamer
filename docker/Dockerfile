FROM perl

RUN cpanm install Mojo::JSON File::Slurp Moose
RUN cpanm install namespace::autoclean
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
CMD /perl/b17.pl
