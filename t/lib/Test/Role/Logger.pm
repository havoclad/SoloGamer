package Test::Role::Logger;

use strict;
use warnings;
use v5.20;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions

use lib '/perl';

extends 'Test::SoloGamer::Base';

sub test_verbose_attribute : Test(3) {
    my $test = shift;
    
    # Test verbose attribute exists and has correct defaults
    require Logger;
    
    # Create a test class that consumes the Logger role
    {
        package TestLogger;
        use Moose;
        with 'Logger';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $logger = TestLogger->new();
    
    # Test default verbose is false
    ok(!$logger->verbose, 'verbose defaults to false');
    
    # Test we can set verbose to true
    my $verbose_logger = TestLogger->new(verbose => 1);
    ok($verbose_logger->verbose, 'verbose can be set to true');
    
    # Test we can set verbose to false explicitly
    my $quiet_logger = TestLogger->new(verbose => 0);
    ok(!$quiet_logger->verbose, 'verbose can be set to false explicitly');
}

sub test_devel_method_quiet : Test(1) {
    my $test = shift;
    
    require Logger;
    
    {
        package TestLogger;
        use Moose;
        with 'Logger';
        __PACKAGE__->meta->make_immutable;
    }
    
    # Create logger with verbose = 0 (default)
    my $logger = TestLogger->new();
    
    # Capture output
    my $output = '';
    {
        local *STDOUT;
        open(STDOUT, '>', \$output) or die "Cannot redirect STDOUT: $!";
        $logger->devel('test message');
    }
    
    # Should produce no output when verbose is false
    is($output, '', 'devel produces no output when verbose is false');
}

sub test_devel_method_verbose : Test(1) {
    my $test = shift;
    
    require Logger;
    
    {
        package TestLogger;
        use Moose;
        with 'Logger';
        __PACKAGE__->meta->make_immutable;
    }
    
    # Create logger with verbose = 1
    my $logger = TestLogger->new(verbose => 1);
    
    # Capture output
    my $output = '';
    {
        local *STDOUT;
        open(STDOUT, '>', \$output) or die "Cannot redirect STDOUT: $!";
        $logger->devel('test message');
    }
    
    # Should produce output when verbose is true
    like($output, qr/test message/, 'devel produces output when verbose is true');
}

sub test_devel_multiple_lines : Test(1) {
    my $test = shift;
    
    require Logger;
    
    {
        package TestLogger;
        use Moose;
        with 'Logger';
        __PACKAGE__->meta->make_immutable;
    }
    
    # Create logger with verbose = 1
    my $logger = TestLogger->new(verbose => 1);
    
    # Capture output
    my $output = '';
    {
        local *STDOUT;
        open(STDOUT, '>', \$output) or die "Cannot redirect STDOUT: $!";
        $logger->devel('line 1', 'line 2', 'line 3');
    }
    
    # Should handle multiple arguments
    like($output, qr/line 1line 2line 3/, 'devel handles multiple arguments');
}

sub test_devel_return_value : Test(1) {
    my $test = shift;
    
    require Logger;
    
    {
        package TestLogger;
        use Moose;
        with 'Logger';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $logger = TestLogger->new();
    
    # Test that devel returns undef as documented
    my $result = $logger->devel('test');
    is($result, undef, 'devel returns undef');
}

1;