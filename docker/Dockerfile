FROM perl

RUN cpanm install File::Slurp
RUN cpanm install namespace::autoclean
RUN cpanm install Moose
RUN cpanm install Mojo::JSON
ADD in/perl.tar.gz /
CMD ["/perl/b17.pl"]
