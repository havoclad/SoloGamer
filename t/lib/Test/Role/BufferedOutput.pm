package Test::Role::BufferedOutput;

use v5.42;

use Test::Class::Moose;
use Test2::V0 ();  # Don't import test functions

use lib '/perl';

extends 'Test::SoloGamer::Base';

sub test_buffered_output_attribute : Test(3) {
    my $test = shift;
    
    require BufferedOutput;
    
    # Create a test class that consumes the BufferedOutput role
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test buffered_output is an ArrayRef
    isa_ok($buffer->buffered_output, 'ARRAY', 'buffered_output is an ArrayRef');
    
    # Test it starts empty
    is(scalar @{$buffer->buffered_output}, 0, 'buffered_output starts empty');
    
    # Test we can set it
    $buffer->buffered_output(['test']);
    is(scalar @{$buffer->buffered_output}, 1, 'buffered_output can be set');
}

sub test_formatter_attribute : Test(2) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test formatter exists and is correct type
    isa_ok($buffer->formatter, 'SoloGamer::Formatter', 'formatter is SoloGamer::Formatter');
    
    # Test it's lazy (should be same object on repeated calls)
    my $formatter1 = $buffer->formatter;
    my $formatter2 = $buffer->formatter;
    is($formatter1, $formatter2, 'formatter is lazy loaded');
}

sub test_buffer_method : Test(3) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test buffering single line
    $buffer->buffer('line 1');
    is(scalar @{$buffer->buffered_output}, 1, 'buffer adds single line');
    is($buffer->buffered_output->[0], 'line 1', 'buffer stores correct content');
    
    # Test buffering multiple lines
    $buffer->buffer('line 2', 'line 3');
    is(scalar @{$buffer->buffered_output}, 3, 'buffer adds multiple lines');
}

sub test_flush_method : Test(2) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Add some content
    $buffer->buffer('line 1', 'line 2');
    is(scalar @{$buffer->buffered_output}, 2, 'buffer has content before flush');
    
    # Flush should clear the buffer
    $buffer->flush();
    is(scalar @{$buffer->buffered_output}, 0, 'flush clears the buffer');
}

sub test_print_output_method : Test(2) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    $buffer->buffer('line 1', 'line 2');
    
    # Capture output
    my $output = '';
    {
        local *STDOUT;
        open(STDOUT, '>', \$output) or die "Cannot redirect STDOUT: $!";
        $buffer->print_output();
    }
    
    # Should print all lines and clear buffer
    like($output, qr/line 1.*line 2/s, 'print_output prints all buffered lines');
    is(scalar @{$buffer->buffered_output}, 0, 'print_output clears buffer');
}

sub test_get_buffer_size : Test(3) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test empty buffer
    is($buffer->get_buffer_size(), -1, 'get_buffer_size returns -1 for empty buffer');
    
    # Test with one item
    $buffer->buffer('line 1');
    is($buffer->get_buffer_size(), 0, 'get_buffer_size returns 0 for one item');
    
    # Test with multiple items
    $buffer->buffer('line 2', 'line 3');
    is($buffer->get_buffer_size(), 2, 'get_buffer_size returns correct size');
}

sub test_flush_to : Test(2) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    $buffer->buffer('line 1', 'line 2', 'line 3', 'line 4');
    
    # Flush to size 1 (keep first 2 elements, indices 0 and 1)
    $buffer->flush_to(1);
    is(scalar @{$buffer->buffered_output}, 2, 'flush_to reduces buffer to correct size');
    is($buffer->buffered_output->[1], 'line 2', 'flush_to keeps correct elements');
}

sub test_buffer_formatting_methods : Test(6) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test each formatting method exists and adds to buffer
    $buffer->buffer_roll('roll text');
    is(scalar @{$buffer->buffered_output}, 1, 'buffer_roll adds to buffer');
    
    $buffer->buffer_success('success text');
    is(scalar @{$buffer->buffered_output}, 2, 'buffer_success adds to buffer');
    
    $buffer->buffer_danger('danger text');
    is(scalar @{$buffer->buffered_output}, 3, 'buffer_danger adds to buffer');
    
    $buffer->buffer_location('location text');
    is(scalar @{$buffer->buffered_output}, 4, 'buffer_location adds to buffer');
    
    $buffer->buffer_important('important text');
    is(scalar @{$buffer->buffered_output}, 5, 'buffer_important adds to buffer');
    
    $buffer->buffer_header('header text', 20);
    is(scalar @{$buffer->buffered_output}, 6, 'buffer_header adds to buffer');
}

sub test_buffer_progress : Test(2) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    # Test progress without label
    $buffer->buffer_progress(5, 10, undef, 20);
    is(scalar @{$buffer->buffered_output}, 1, 'buffer_progress without label adds to buffer');
    
    # Test progress with label
    $buffer->buffer_progress(7, 10, 'Loading', 20);
    is(scalar @{$buffer->buffered_output}, 2, 'buffer_progress with label adds to buffer');
}

sub test_buffer_table : Test(1) {
    my $test = shift;
    
    require BufferedOutput;
    
    {
        package TestBufferedOutput;
        use Moose;
        with 'BufferedOutput';
        __PACKAGE__->meta->make_immutable;
    }
    
    my $buffer = TestBufferedOutput->new();
    
    $buffer->buffer_table('Test Table', [['col1', 'col2'], ['val1', 'val2']]);
    is(scalar @{$buffer->buffered_output}, 1, 'buffer_table adds to buffer');
}

1;