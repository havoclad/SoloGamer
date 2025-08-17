package SoloGamer::QotS::PlaneNamer;

use v5.42;

use Carp;
use File::Slurp;
use List::Util qw(shuffle);

use Moose;
use namespace::autoclean;

with 'Logger';

has 'generated_names_file' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/games/QotS/generated_b17_bomber_names.txt',
);

has 'verified_names_file' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/games/QotS/verified_b17_bomber_names.txt',
);

has 'automated' => (
  is       => 'ro',
  isa      => 'Bool',
  init_arg => 'automated',
  default  => 0,
);

has 'input_file' => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'input_file',
  default  => '',
);

has '_input_fh' => (
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_input_fh',
  clearer  => '_clear_input_fh',
);

sub get_random_name {
  my $self = shift;
  my $use_verified = shift // 0;
  
  my $file = $use_verified ? $self->verified_names_file : $self->generated_names_file;
  
  if (! -e $file) {
    $self->devel("Name file not found: $file, trying other file");
    $file = $use_verified ? $self->generated_names_file : $self->verified_names_file;
    
    if (! -e $file) {
      croak "Neither name file found: " . $self->generated_names_file . " or " . $self->verified_names_file;
    }
  }
  
  my @names = read_file($file, chomp => 1);
  @names = grep { $_ && $_ !~ /^\s*$/ } @names;  # Remove empty lines
  
  if (@names == 0) {
    croak "No names found in file: $file";
  }
  
  my @shuffled = shuffle(@names);
  return $shuffled[0];
}

sub _build_input_fh {
  my $self = shift;
  
  return undef unless $self->input_file;
  
  open my $fh, '<', $self->input_file
    or croak "Cannot open input file '" . $self->input_file . "': $!";
  return $fh;
}

sub _get_input {
  my $self = shift;
  my $prompt = shift;
  my $options = shift || {};
  
  # In automated mode, just return default if available
  if ($self->automated) {
    return $options->{default} if exists $options->{default};
    return '';
  }
  
  # If input_file is provided, read from file
  if ($self->input_file && $self->_input_fh) {
    my $line = readline($self->_input_fh);
    if (defined $line) {
      chomp $line;
      say "Reading from input file: $line" if $self->can('devel');
      return $line;
    } else {
      # EOF reached, fall back to default if available
      return $options->{default} if exists $options->{default};
      return '';
    }
  }
  
  # Check if IO::Prompter is available and we should use it
  my $use_prompter = 0;
  eval {
    require IO::Prompter;
    IO::Prompter->import();
    # Use IO::Prompter unless we have an input_file (for scripted mode)
    $use_prompter = 1;
  };
  
  if ($use_prompter && $options->{menu}) {
    # Use IO::Prompter for menu-based prompts
    my $choice = prompt(
      $prompt,
      -menu => $options->{menu},
      -default => $options->{default} // '',
      -prompt => 'Your choice: ',
    );
    return defined $choice ? "$choice" : ($options->{default} // '');
  } elsif ($use_prompter) {
    # Use IO::Prompter for simple prompts
    my $response = prompt(
      $prompt,
      -default => $options->{default} // '',
    );
    return defined $response ? "$response" : ($options->{default} // '');
  } else {
    # Fallback to STDIN for tests
    print $prompt;
    print " Your choice: " if $options->{menu};
    my $input = <STDIN>;
    chomp $input if defined $input;
    return defined $input ? $input : ($options->{default} // '');
  }
}

sub prompt_for_plane_name {
  my $self = shift;
  
  # In automated mode, just return a random name
  if ($self->automated) {
    my $name = $self->get_random_name();
    say "Automated mode: Selected plane name '$name'";
    return $name;
  }
  
  my $suggested_name = $self->get_random_name();
  
  print "\n";
  print "=" x 50 . "\n";
  print "PLANE NAMING\n";
  print "=" x 50 . "\n";
  print "Your B-17 needs a name for this mission series.\n";
  print "Suggested name: $suggested_name\n\n";
  
  while (1) {
    my $choice = $self->_get_input(
      "Choose an option:",
      {
        menu => {
          "Accept suggested name ($suggested_name)" => 'accept',
          'Reroll for a new random name' => 'reroll',
          'Get a name from the verified historical list' => 'verified',
          'Enter a custom name' => 'custom',
        },
        default => 'accept',
      }
    );
    
    # Handle empty choice as accept
    if (!defined $choice || $choice eq '') {
      return $suggested_name;
    }
    
    if ($choice eq 'accept') {
      return $suggested_name;
    } elsif ($choice eq 'reroll' || $choice eq 'r') {
      $suggested_name = $self->get_random_name();
      print "New suggested name: $suggested_name\n";
    } elsif ($choice eq 'verified' || $choice eq 'v') {
      $suggested_name = $self->get_random_name(1);  # Use verified list
      print "Historical name: $suggested_name\n";
    } elsif ($choice eq 'custom' || $choice eq 'c') {
      my $custom_name = $self->_get_input("Enter your custom plane name:");
      if (defined $custom_name && length($custom_name) > 0) {
        return $custom_name;
      } else {
        print "Invalid name. Please try again.\n";
      }
    } else {
      print "Invalid choice. Please try again.\n";
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;