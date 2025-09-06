package SoloGamer::ColorScheme::Registry;
use v5.42;
use utf8;

use Moose;
use Module::Runtime qw(require_module);

has 'schemes' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_schemes',
);

has 'default_scheme_name' => (
  is      => 'ro',
  isa     => 'Str',
  default => 'terminal_classic',
);

sub _build_schemes {
  my $self = shift;
  
  my %schemes;
  
  # Load all available color schemes
  my @scheme_classes = qw(
    SoloGamer::ColorScheme::MilitaryGreen
    SoloGamer::ColorScheme::ClassicAviation
    SoloGamer::ColorScheme::VintageWWII
    SoloGamer::ColorScheme::TerminalClassic
  );
  
  # Define scheme mappings to avoid if-elsif chain
  my %scheme_mappings = (
    'SoloGamer::ColorScheme::MilitaryGreen' => {
      keys => ['military_green', 'military'],
      legacy_key => 1,
    },
    'SoloGamer::ColorScheme::ClassicAviation' => {
      keys => ['classic_aviation', 'aviation'],
      legacy_key => 2,
    },
    'SoloGamer::ColorScheme::VintageWWII' => {
      keys => ['vintage_wwii', 'vintage', 'wwii'],
      legacy_key => 3,
    },
    'SoloGamer::ColorScheme::TerminalClassic' => {
      keys => ['terminal_classic', 'terminal'],
      legacy_key => 4,
    },
  );
  
  foreach my $class (@scheme_classes) {
    require_module($class);
    my $scheme = $class->new();
    
    # Create multiple keys for each scheme for backwards compatibility and convenience
    if (exists $scheme_mappings{$class}) {
      my $mapping = $scheme_mappings{$class};
      
      # Add all standard keys
      foreach my $key (@{$mapping->{keys}}) {
        $schemes{$key} = $scheme;
      }
      
      # Add legacy numeric key for backwards compatibility
      $schemes{$mapping->{legacy_key}} = $scheme;
    }
  }
  
  return \%schemes;
}

sub get_scheme {
  my ($self, $identifier) = @_;
  
  # If no identifier provided, check environment variable
  unless (defined $identifier) {
    # Support both old and new environment variable names
    $identifier = $ENV{COLOR_SCHEME} // $ENV{BANNER_COLOR_SCHEME} // $self->default_scheme_name;
  }
  
  # Normalize the identifier (lowercase, replace spaces with underscores)
  $identifier = lc($identifier);
  $identifier =~ s/\s+/_/gsx;
  
  # Return the scheme if found, otherwise return default
  return $self->schemes->{$identifier} // $self->schemes->{$self->default_scheme_name};
}

sub list_schemes {
  my $self = shift;
  
  my %unique_schemes;
  foreach my $scheme (values %{$self->schemes}) {
    $unique_schemes{$scheme->name} = {
      name        => $scheme->name,
      description => $scheme->description,
    };
  }
  my @sorted = sort { $a->{name} cmp $b->{name} } values %unique_schemes;
  return @sorted;
}

__PACKAGE__->meta->make_immutable;
1;