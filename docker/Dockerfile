FROM perl

# Install available packages via apt
RUN apt-get update && apt-get install -y \
    libmoose-perl \
    libnamespace-autoclean-perl \
    libtest-exception-perl \
    && rm -rf /var/lib/apt/lists/*

# Install remaining packages via cpanm (some debian packages don't work correctly)
RUN cpanm install Mojo::JSON File::Slurp MooseX::Singleton MooseX::Types Test::MockObject Perl::Critic Test::Class::Moose Test2::Suite Devel::Cover
ADD in/perl.tar.gz /
ADD in/data.tar.gz /
ENTRYPOINT ["/perl/SoloGamer.pl"]
