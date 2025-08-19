package SoloGamer::QotS::PlaneNamer;

use v5.42;

use Carp;
use File::Slurp;
use IO::Prompter;
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
  
  return unless $self->input_file;
  
  open my $fh, '<', $self->input_file
    or croak "Cannot open input file '" . $self->input_file . "': $!";
  return $fh;
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
    my $choice = prompt
      'Choose an option:',
      -number,
      -menu => {
        "Accept suggested name ($suggested_name)" => 'a',
        'Reroll for a new random name' => 'r',
        'Get a name from the verified historical list' => 'h',
        'Enter a custom name' => 'c',
        },
      -default => 'a',
      '>',
    ;
    if ($choice eq 'a') {
      return $suggested_name;
    } elsif ($choice eq 'r') {
      $suggested_name = $self->get_random_name();
      print "New suggested name: $suggested_name\n";
    } elsif ($choice eq 'h') {
      $suggested_name = $self->get_random_name(1);  # Use verified list
      print "Historical name: $suggested_name\n";
    } elsif ($choice eq 'c') {
      my $custom_name = prompt 'Enter your custom plane name:';
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