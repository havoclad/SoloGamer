package SoloGamer::QotS::CrewNamer;

use v5.42;

use Carp;
use HavocLad::File::RandomLine qw(random_line);
use IO::Prompter;
use SoloGamer::Formatter;

use Moose;
use namespace::autoclean;

with 'Logger';
with 'BufferedOutput';

has 'first_names_file' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/games/QotS/1940s_male_first_names.txt',
);

has 'last_names_file' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/games/QotS/1940s_male_last_names.txt',
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

has 'formatter' => (
  is      => 'ro',
  isa     => 'SoloGamer::Formatter',
  default => sub { SoloGamer::Formatter->new() },
  lazy    => 1,
);

sub get_random_name {
  my $self = shift;
  
  my $first_name = random_line($self->first_names_file);
  my $last_name = random_line($self->last_names_file);
  
  return $first_name . ' ' . $last_name;
}

sub get_random_names {
  my $self = shift;
  my $count = shift || 10;
  
  my @names;
  my %used;
  
  while (@names < $count) {
    my $name = $self->get_random_name();
    if (!exists $used{$name}) {
      push @names, $name;
      $used{$name} = 1;
    }
  }
  
  return @names;
}

sub _build_input_fh {
  my $self = shift;
  
  return unless $self->input_file;
  
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
  
  my @extra_options = ();
  if ($options->{menu}) {
    push @extra_options, -menu => $options->{menu};
  }
  my $choice = prompt(
    $prompt,
    -default => $options->{default} // '',
    @extra_options,
  );
    return defined $choice ? "$choice" : ($options->{default} // '');
}

sub _handle_accept_choice {
  my ($self, $positions, $suggested_names) = @_;
  
  my @crew_names;
  for (my $i = 0; $i < 10; $i++) {
    push @crew_names, {
      position => $positions->[$i],
      name => $suggested_names->[$i]
    };
  }
  return \@crew_names;
}

sub _handle_reroll_choice {
  my ($self, $positions, $suggested_names_ref) = @_;
  
  @$suggested_names_ref = $self->get_random_names(10);
  $self->buffer("");
  $self->print_output();
  return; # Continue loop
}

sub _handle_individual_choice {
  my ($self, $positions, $suggested_names) = @_;
  
  my @crew_names;
  $self->buffer("");
  $self->buffer("Naming crew individually:");
  $self->print_output();
  
  for (my $i = 0; $i < 10; $i++) {
    $self->buffer("");
    $self->buffer("$positions->[$i] (suggested: $suggested_names->[$i])");
    $self->print_output();
    
    my $name_choice = $self->_get_input(
      "Enter name or press Enter to accept suggestion:",
      { default => $suggested_names->[$i] }
    );
    
    push @crew_names, {
      position => $positions->[$i],
      name => $name_choice || $suggested_names->[$i]
    };
  }
  return \@crew_names;
}

sub _handle_custom_choice {
  my ($self, $positions, $suggested_names) = @_;
  
  my @crew_names;
  $self->buffer("");
  $self->buffer("Enter custom names for each position:");
  $self->print_output();
  
  for (my $i = 0; $i < 10; $i++) {
    my $custom_name = $self->_get_input(
      "$positions->[$i]:",
      { default => $suggested_names->[$i] }
    );
    
    push @crew_names, {
      position => $positions->[$i],
      name => $custom_name || $suggested_names->[$i]
    };
  }
  return \@crew_names;
}

sub prompt_for_crew_names {
  my $self = shift;
  my $positions = shift;
  
  if (!$positions || ref($positions) ne 'ARRAY' || @$positions != 10) {
    croak "Must provide exactly 10 crew positions";
  }
  
  my @crew_names;
  my @suggested_names = $self->get_random_names(10);
  
  if ($self->automated) {
    for (my $i = 0; $i < 10; $i++) {
      push @crew_names, {
        position => $positions->[$i],
        name => $suggested_names[$i]
      };
    }
    say "Automated mode: Generated crew roster";
    return \@crew_names;
  }
  
  # Use formatter to create a nice boxed header like the Welcome header
  $self->buffer("");
  $self->buffer_header("CREW NAMING", 50);
  $self->buffer("Your B-17 crew needs names.");
  $self->buffer("");
  $self->print_output();
  
  while (1) {
    $self->buffer("Suggested crew roster:");
    for (my $i = 0; $i < 10; $i++) {
      $self->buffer(sprintf "  %-25s %s", $positions->[$i] . ":", $suggested_names[$i]);
    }
    $self->print_output();
    
    my $choice = $self->_get_input(
      "\nChoose an option:",
      {
        menu => {
          'Accept all suggested names' => 'accept',
          'Reroll all names' => 'reroll',
          'Name crew individually' => 'individual',
          'Enter all custom names' => 'custom',
        },
        default => 'accept',
      }
    );
    
    # Handle empty choice as accept
    if (!defined $choice || $choice eq '') {
      return $self->_handle_accept_choice($positions, \@suggested_names);
    }
    
    # Define dispatch table for choice handlers
    my %choice_handlers = (
      'accept'     => sub { return $self->_handle_accept_choice($positions, \@suggested_names) },
      'reroll'     => sub { return $self->_handle_reroll_choice($positions, \@suggested_names) },
      'r'          => sub { return $self->_handle_reroll_choice($positions, \@suggested_names) },
      'individual' => sub { return $self->_handle_individual_choice($positions, \@suggested_names) },
      'i'          => sub { return $self->_handle_individual_choice($positions, \@suggested_names) },
      'custom'     => sub { return $self->_handle_custom_choice($positions, \@suggested_names) },
      'c'          => sub { return $self->_handle_custom_choice($positions, \@suggested_names) },
    );
    
    # Dispatch to appropriate handler or show error
    if (exists $choice_handlers{$choice}) {
      my $result = $choice_handlers{$choice}->();
      return $result if defined $result; # Return if we have a result, otherwise continue loop
    } else {
      $self->buffer("Invalid choice. Please try again.");
      $self->print_output();
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;