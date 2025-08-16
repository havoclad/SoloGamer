package SoloGamer::QotS::CrewNamer;

use v5.42;

use Carp;
use File::Slurp;
use List::Util qw(shuffle);

use Moose;
use namespace::autoclean;

with 'Logger';

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

has '_first_names' => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  builder => '_build_first_names',
);

has '_last_names' => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  builder => '_build_last_names',
);

sub _build_first_names {
  my $self = shift;
  
  if (! -e $self->first_names_file) {
    croak "First names file not found: " . $self->first_names_file;
  }
  
  my @names = read_file($self->first_names_file, chomp => 1);
  @names = grep { $_ && $_ !~ /^\s*$/ } @names;
  
  if (@names == 0) {
    croak "No first names found in file: " . $self->first_names_file;
  }
  
  return \@names;
}

sub _build_last_names {
  my $self = shift;
  
  if (! -e $self->last_names_file) {
    croak "Last names file not found: " . $self->last_names_file;
  }
  
  my @names = read_file($self->last_names_file, chomp => 1);
  @names = grep { $_ && $_ !~ /^\s*$/ } @names;
  
  if (@names == 0) {
    croak "No last names found in file: " . $self->last_names_file;
  }
  
  return \@names;
}

sub get_random_name {
  my $self = shift;
  
  my @first_shuffled = shuffle(@{$self->_first_names});
  my @last_shuffled = shuffle(@{$self->_last_names});
  
  return $first_shuffled[0] . ' ' . $last_shuffled[0];
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
  
  print "\n";
  print "=" x 50 . "\n";
  print "CREW NAMING\n";
  print "=" x 50 . "\n";
  print "Your B-17 crew needs names.\n\n";
  
  print "Suggested crew roster:\n";
  for (my $i = 0; $i < 10; $i++) {
    printf "  %-25s %s\n", $positions->[$i] . ":", $suggested_names[$i];
  }
  
  print "\nOptions:\n";
  print "  [Enter] - Accept all suggested names\n";
  print "  r - Reroll all names\n";
  print "  i - Name crew individually\n";
  print "  c - Enter all custom names\n";
  print "Choice: ";
  
  while (1) {
    my $choice = <STDIN>;
    chomp $choice if defined $choice;
    $choice //= '';
    $choice = lc($choice);
    
    if ($choice eq '' || $choice eq "\n") {
      for (my $i = 0; $i < 10; $i++) {
        push @crew_names, {
          position => $positions->[$i],
          name => $suggested_names[$i]
        };
      }
      return \@crew_names;
      
    } elsif ($choice eq 'r') {
      @suggested_names = $self->get_random_names(10);
      print "\nNew crew roster:\n";
      for (my $i = 0; $i < 10; $i++) {
        printf "  %-25s %s\n", $positions->[$i] . ":", $suggested_names[$i];
      }
      print "Choice (Enter/r/i/c): ";
      
    } elsif ($choice eq 'i') {
      print "\nNaming crew individually:\n";
      for (my $i = 0; $i < 10; $i++) {
        print "\n$positions->[$i]:\n";
        print "  Suggested: $suggested_names[$i]\n";
        print "  [Enter] to accept, or type a custom name: ";
        
        my $name_choice = <STDIN>;
        chomp $name_choice if defined $name_choice;
        
        if (!defined $name_choice || $name_choice eq '') {
          push @crew_names, {
            position => $positions->[$i],
            name => $suggested_names[$i]
          };
        } else {
          push @crew_names, {
            position => $positions->[$i],
            name => $name_choice
          };
        }
      }
      return \@crew_names;
      
    } elsif ($choice eq 'c') {
      print "\nEnter custom names for each position:\n";
      for (my $i = 0; $i < 10; $i++) {
        print "$positions->[$i]: ";
        my $custom_name = <STDIN>;
        chomp $custom_name if defined $custom_name;
        
        if (!defined $custom_name || $custom_name eq '') {
          print "Invalid name. Using suggested: $suggested_names[$i]\n";
          push @crew_names, {
            position => $positions->[$i],
            name => $suggested_names[$i]
          };
        } else {
          push @crew_names, {
            position => $positions->[$i],
            name => $custom_name
          };
        }
      }
      return \@crew_names;
      
    } else {
      print "Invalid choice. Choice (Enter/r/i/c): ";
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;