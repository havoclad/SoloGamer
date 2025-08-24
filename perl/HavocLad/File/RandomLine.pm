package HavocLad::File::RandomLine;
use v5.36;

use Carp;
use File::Slurp;
use List::Util qw(shuffle);
use Exporter 'import';

our @EXPORT_OK = qw(random_line);

sub random_line {
  my $filename = shift;

  my @lines = grep { $_ && $_ !~ /^\s*$/x } # Remove empty lines
    read_file($filename, chomp => 1);
  
  @lines || croak "Nothing found in file: $filename";
  
  my @shuffled = shuffle(@lines);
  return $shuffled[0];
}

1;

__END__

=head1 NAME

HavocLad::File::RandomLine - Select a random non-empty line from a file

=head1 SYNOPSIS

  use HavocLad::File::RandomLine qw(random_line);
  
  # Get a random line from a file
  my $line = random_line('/path/to/file.txt');
  
  # Use for random name selection
  my $name = random_line('data/names.txt');
  
  # Use for random quote selection
  my $quote = random_line('data/quotes.txt');

=head1 DESCRIPTION

This module provides a simple utility function to select a random line from a
text file. Empty lines and lines containing only whitespace are automatically
filtered out before selection.

The module is particularly useful for:

=over 4

=item * Selecting random names for game characters

=item * Choosing random quotes or messages

=item * Picking random items from lists stored in files

=item * Any scenario requiring random selection from file-based data

=back

=head1 FUNCTIONS

=head2 random_line

  my $line = random_line($filename);

Reads all lines from the specified file, filters out empty lines and lines
containing only whitespace, and returns one randomly selected line.

=head3 Parameters

=over 4

=item * C<$filename> - Path to the file to read from (required)

=back

=head3 Returns

A randomly selected non-empty line from the file, with line endings removed.

=head3 Exceptions

Dies with an error message if:

=over 4

=item * The file cannot be opened or read

=item * The file is empty

=item * The file contains only empty lines or whitespace

=back

=head1 EXAMPLES

=head2 Basic Usage

  use HavocLad::File::RandomLine qw(random_line);
  
  my $random_word = random_line('dictionary.txt');
  print "Word of the day: $random_word\n";

=head2 Error Handling

  use HavocLad::File::RandomLine qw(random_line);
  use Try::Tiny;
  
  try {
      my $line = random_line('maybe-missing.txt');
      print "Got: $line\n";
  }
  catch {
      warn "Could not get random line: $_";
  };

=head2 Multiple Selections

  use HavocLad::File::RandomLine qw(random_line);
  
  # Get 5 random names (may include duplicates)
  my @team;
  for (1..5) {
      push @team, random_line('crew-names.txt');
  }
  print "Your crew: ", join(', ', @team), "\n";

=head1 DEPENDENCIES

=over 4

=item * L<File::Slurp> - For efficient file reading

=item * L<List::Util> - For the shuffle function

=item * L<Carp> - For error reporting

=back

=head1 AUTHOR

HavocLad

=head1 LICENSE

This module is part of the SoloGamer project.

=head1 SEE ALSO

L<File::Slurp>, L<List::Util>

=cut