package SoloGamer::QotS::PlaneNamer;

use v5.42;

use Carp;
use HavocLad::File::RandomLine qw(random_line);
use IO::Prompter;
use Term::ReadKey;

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
  
  return random_line($file);
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
  
  while (prompt "[A]ccept suggested name($suggested_name), roll a (N)ew name, roll a (H)istorical name, Enter a (C)ustom name", -keyletters, -single) {
    if (/A/i) { return $suggested_name }
    if (/N/i) { $suggested_name = $self->get_random_name() }
    if (/H/i) { $suggested_name = $self->get_random_name(1) }
    if (/C/i) { return prompt 'Enter your custom plane name' }
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;