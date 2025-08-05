# Build stage - includes build dependencies
FROM perl:5.42-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Perl modules that require compilation
RUN cpanm install Mojo::JSON File::Slurp MooseX::Singleton MooseX::Types Test::MockObject Perl::Critic Test::Class::Moose Test2::Suite Devel::Cover

# Runtime stage - minimal dependencies only
FROM perl:5.42-slim AS runtime

LABEL org.opencontainers.image.description="SoloGamer - B-17 Queen of the Skies automation engine"
LABEL org.opencontainers.image.version="0.1"
LABEL org.opencontainers.image.source="https://github.com/havodlad/SoloGamer"
LABEL maintainer="havoc@boldo.com"
LABEL org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# Create non-root user
RUN groupadd -r sologamer && useradd -r -g sologamer sologamer

# Install only runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y \
    libmoose-perl \
    libnamespace-autoclean-perl \
    libtest-exception-perl \
    && rm -rf /var/lib/apt/lists/*

# Copy Perl modules from builder stage
COPY --from=builder /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=builder /usr/local/bin /usr/local/bin

ADD in/perl.tar.gz /
ADD in/data.tar.gz /

# Set proper ownership for non-root user
RUN chown -R sologamer:sologamer /perl /games

# Switch to non-root user
USER sologamer

ENTRYPOINT ["/perl/SoloGamer.pl"]
