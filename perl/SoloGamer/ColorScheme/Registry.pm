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
  
  foreach my $class (@scheme_classes) {
    require_module($class);
    my $scheme = $class->new();
    
    # Create multiple keys for each scheme for backwards compatibility and convenience
    # e.g., MilitaryGreen can be accessed as: military_green, military, 1
    if ($class =~ /MilitaryGreen/) {
      $schemes{military_green} = $scheme;
      $schemes{military} = $scheme;
      $schemes{1} = $scheme;  # Backwards compatibility
    }
    elsif ($class =~ /ClassicAviation/) {
      $schemes{classic_aviation} = $scheme;
      $schemes{aviation} = $scheme;
      $schemes{2} = $scheme;  # Backwards compatibility
    }
    elsif ($class =~ /VintageWWII/) {
      $schemes{vintage_wwii} = $scheme;
      $schemes{vintage} = $scheme;
      $schemes{wwii} = $scheme;
      $schemes{3} = $scheme;  # Backwards compatibility
    }
    elsif ($class =~ /TerminalClassic/) {
      $schemes{terminal_classic} = $scheme;
      $schemes{terminal} = $scheme;
      $schemes{4} = $scheme;  # Backwards compatibility
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
  $identifier =~ s/\s+/_/g;
  
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
  
  return sort { $a->{name} cmp $b->{name} } values %unique_schemes;
}

__PACKAGE__->meta->make_immutable;
1;