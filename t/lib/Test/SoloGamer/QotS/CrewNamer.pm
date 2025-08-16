package Test::SoloGamer::QotS::CrewNamer;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Slurp;

use SoloGamer::QotS::CrewNamer;

has 'test_dir' => (
  is      => 'ro',
  isa     => 'Str',
  default => sub { tempdir(CLEANUP => 1) },
);

sub test_setup {
  my $test = shift;
  
  # Create test name files
  my $first_names = join("\n", qw(John James Robert William Richard));
  my $last_names = join("\n", qw(Smith Johnson Williams Brown Jones));
  
  write_file($test->test_dir . '/first_names.txt', $first_names);
  write_file($test->test_dir . '/last_names.txt', $last_names);
}

sub test_constructor {
  my $test = shift;
  
  my $namer = SoloGamer::QotS::CrewNamer->new();
  isa_ok($namer, 'SoloGamer::QotS::CrewNamer', 'Constructor creates correct object');
  
  is($namer->first_names_file, '/games/QotS/1940s_male_first_names.txt', 
     'Default first names file path is correct');
  is($namer->last_names_file, '/games/QotS/1940s_male_last_names.txt',
     'Default last names file path is correct');
  is($namer->automated, 0, 'Default automated mode is false');
}

sub test_get_random_name {
  my $test = shift;
  
  my $namer = SoloGamer::QotS::CrewNamer->new(
    first_names_file => $test->test_dir . '/first_names.txt',
    last_names_file  => $test->test_dir . '/last_names.txt',
  );
  
  my $name = $namer->get_random_name();
  ok($name, 'get_random_name returns a name');
  like($name, qr/^\w+ \w+$/, 'Name has correct format (first last)');
  
  # Check name components are from our test files
  my ($first, $last) = split(' ', $name);
  ok(grep { $_ eq $first } qw(John James Robert William Richard), 
     'First name is from test file');
  ok(grep { $_ eq $last } qw(Smith Johnson Williams Brown Jones),
     'Last name is from test file');
}

sub test_get_random_names {
  my $test = shift;
  
  my $namer = SoloGamer::QotS::CrewNamer->new(
    first_names_file => $test->test_dir . '/first_names.txt',
    last_names_file  => $test->test_dir . '/last_names.txt',
  );
  
  my @names = $namer->get_random_names(3);
  is(scalar(@names), 3, 'get_random_names returns requested count');
  
  # Check for uniqueness
  my %seen;
  foreach my $name (@names) {
    ok(!exists $seen{$name}, "Name '$name' is unique");
    $seen{$name} = 1;
  }
  
  # Test default count
  @names = $namer->get_random_names();
  is(scalar(@names), 10, 'get_random_names defaults to 10 names');
}

sub test_automated_mode {
  my $test = shift;
  
  my $namer = SoloGamer::QotS::CrewNamer->new(
    first_names_file => $test->test_dir . '/first_names.txt',
    last_names_file  => $test->test_dir . '/last_names.txt',
    automated        => 1,
  );
  
  my $positions = [
    'bombardier', 'navigator', 'pilot', 'copilot', 'engineer',
    'radio_operator', 'ball_gunner', 'port_waist_gunner',
    'starboard_waist_gunner', 'tail_gunner'
  ];
  
  my $crew_names = $namer->prompt_for_crew_names($positions);
  
  isa_ok($crew_names, 'ARRAY', 'prompt_for_crew_names returns array ref');
  is(scalar(@$crew_names), 10, 'Returns 10 crew members');
  
  foreach my $crew_info (@$crew_names) {
    isa_ok($crew_info, 'HASH', 'Each crew info is a hash');
    ok(exists $crew_info->{position}, 'Has position key');
    ok(exists $crew_info->{name}, 'Has name key');
    like($crew_info->{name}, qr/^\w+ \w+$/, 'Name has correct format');
  }
}

sub test_error_handling {
  my $test = shift;
  
  # Test missing files
  my $namer = SoloGamer::QotS::CrewNamer->new(
    first_names_file => '/nonexistent/file.txt',
    last_names_file  => '/nonexistent/file2.txt',
  );
  
  throws_ok { $namer->get_random_name() }
            qr/First names file not found/,
            'Dies when first names file not found';
  
  # Test invalid positions count
  $namer = SoloGamer::QotS::CrewNamer->new(
    first_names_file => $test->test_dir . '/first_names.txt',
    last_names_file  => $test->test_dir . '/last_names.txt',
    automated        => 1,
  );
  
  throws_ok { $namer->prompt_for_crew_names(['pilot']) }
            qr/Must provide exactly 10 crew positions/,
            'Dies when wrong number of positions provided';
}

__PACKAGE__->meta->make_immutable;
1;