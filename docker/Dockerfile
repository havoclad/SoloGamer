FROM perl

RUN cpanm install JSON::Parse JSON::Tiny
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
CMD /perl/b17.pl
