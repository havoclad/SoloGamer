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
      for (my $i = 0; $i < 10; $i++) {
        push @crew_names, {
          position => $positions->[$i],
          name => $suggested_names[$i]
        };
      }
      return \@crew_names;
    }
    
    if ($choice eq 'accept') {
      for (my $i = 0; $i < 10; $i++) {
        push @crew_names, {
          position => $positions->[$i],
          name => $suggested_names[$i]
        };
      }
      return \@crew_names;
      
    } elsif ($choice eq 'reroll' || $choice eq 'r') {
      @suggested_names = $self->get_random_names(10);
      $self->buffer("");
      $self->print_output();
      # Loop continues, will show new roster
      
    } elsif ($choice eq 'individual' || $choice eq 'i') {
      $self->buffer("");
      $self->buffer("Naming crew individually:");
      $self->print_output();
      for (my $i = 0; $i < 10; $i++) {
        $self->buffer("");
        $self->buffer("$positions->[$i] (suggested: $suggested_names[$i])");
        $self->print_output();
        
        my $name_choice = $self->_get_input(
          "Enter name or press Enter to accept suggestion:",
          { default => $suggested_names[$i] }
        );
        
        push @crew_names, {
          position => $positions->[$i],
          name => $name_choice || $suggested_names[$i]
        };
      }
      return \@crew_names;
      
    } elsif ($choice eq 'custom' || $choice eq 'c') {
      $self->buffer("");
      $self->buffer("Enter custom names for each position:");
      $self->print_output();
      for (my $i = 0; $i < 10; $i++) {
        my $custom_name = $self->_get_input(
          "$positions->[$i]:",
          { default => $suggested_names[$i] }
        );
        
        push @crew_names, {
          position => $positions->[$i],
          name => $custom_name || $suggested_names[$i]
        };
      }
      return \@crew_names;
      
    } else {
      $self->buffer("Invalid choice. Please try again.");
      $self->print_output();
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;