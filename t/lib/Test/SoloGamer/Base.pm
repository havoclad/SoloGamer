package Test::SoloGamer::Base;

use v5.42;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions, just load the module
use File::Temp;
use Test::MockObject;

use lib '/perl';

sub test_startup {
    my $test = shift;
    
    # Set up temporary directory for test files
    $test->{temp_dir} = File::Temp->newdir();
    
    # Create mock logger for tests that need it
    $test->{mock_logger} = Test::MockObject->new();
    $test->{mock_logger}->mock('info', sub { return });
    $test->{mock_logger}->mock('debug', sub { return });
    $test->{mock_logger}->mock('devel', sub { return });
    $test->{mock_logger}->mock('error', sub { return });
    $test->{mock_logger}->mock('warn', sub { return });
    $test->{mock_logger}->mock('verbose', sub { return 0 });
}

sub test_shutdown {
    my $test = shift;
    
    # Clean up any test data
    delete $test->{temp_dir};
    delete $test->{mock_logger};
}

sub test_setup {
    my $test = shift;
    
    # Per-test setup - override in subclasses if needed
}

sub test_teardown {
    my $test = shift;
    
    # Per-test cleanup - override in subclasses if needed
}

# Helper method to create temporary JSON files for testing
sub create_temp_json_file {
    my ($test, $data) = @_;
    
    require Mojo::JSON;
    
    my $fh = File::Temp->new(
        DIR => $test->{temp_dir},
        SUFFIX => '.json',
        UNLINK => 0
    );
    
    print $fh Mojo::JSON::encode_json($data);
    close $fh;
    
    return $fh->filename;
}

# Helper method to create a mock SoloGamer::Base object
sub create_mock_base_object {
    my ($test, %args) = @_;
    
    my $mock = Test::MockObject->new();
    $mock->set_isa('SoloGamer::Base');
    
    # Mock the Logger role methods
    $mock->mock('info', sub { return });
    $mock->mock('debug', sub { return });
    $mock->mock('devel', sub { return });
    $mock->mock('error', sub { return });
    $mock->mock('warn', sub { return });
    $mock->mock('verbose', sub { return $args{verbose} // 0 });
    
    return $mock;
}

1;