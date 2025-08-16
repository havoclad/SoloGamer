package Test::SoloGamer::QotS::PlaneNamer;

use strict;
use warnings;
use v5.20;

use Test2::V0;
use File::Temp;
use File::Path qw(make_path);

use Test::Class::Moose;

extends 'Test::Class::Moose';

with 'Test::Class::Moose::Role::AutoUse' => {
    autouse => [qw/SoloGamer::QotS::PlaneNamer/]
};

sub test_startup {
    my ($test, $report) = @_;
    
    # Create temporary directory and name files for testing
    my $temp_dir = File::Temp->newdir();
    $test->{temp_dir} = $temp_dir;
    
    # Create test name files
    my $generated_names = join("\n", qw(
        Sky Bomber
        Thunder Bird
        Hell's Angels
        Memphis Belle
        Flying Fortress
    ));
    
    my $verified_names = join("\n", qw(
        Hell's Angels
        Memphis Belle
        Yankee Doodle
        Ball of Fire
        Shoo Shoo Shoo Baby
    ));
    
    my $games_dir = "$temp_dir/games/QotS";
    make_path($games_dir);
    
    open my $gen_fh, '>', "$games_dir/generated_b17_bomber_names.txt";
    print $gen_fh $generated_names;
    close $gen_fh;
    
    open my $ver_fh, '>', "$games_dir/verified_b17_bomber_names.txt";
    print $ver_fh $verified_names;
    close $ver_fh;
    
    $test->{generated_file} = "$games_dir/generated_b17_bomber_names.txt";
    $test->{verified_file} = "$games_dir/verified_b17_bomber_names.txt";
}

sub test_automated_mode {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 1,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Capture output to test automated selection
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    
    ok(defined $name, 'automated mode returns a name');
    ok(length($name) > 0, 'name is not empty');
    like($output, qr/Automated mode: Selected plane name/, 'automated mode message displayed');
    like($output, qr/\Q$name\E/, 'selected name appears in output');
}

sub test_get_random_name_generated {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    my $name = $namer->get_random_name();
    ok(defined $name, 'get_random_name returns a name');
    ok(length($name) > 0, 'name is not empty');
    
    # Should be one of our test names
    my @expected_names = qw(Sky\ Bomber Thunder\ Bird Hell\'s\ Angels Memphis\ Belle Flying\ Fortress);
    my $found = 0;
    for my $expected (@expected_names) {
        $expected =~ s/\\//g;  # Remove escapes
        if ($name eq $expected) {
            $found = 1;
            last;
        }
    }
    ok($found, 'name comes from generated names file');
}

sub test_get_random_name_verified {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    my $name = $namer->get_random_name(1);  # Use verified list
    ok(defined $name, 'get_random_name with verified flag returns a name');
    ok(length($name) > 0, 'verified name is not empty');
    
    # Should be one of our verified test names
    my @expected_names = qw(Hell\'s\ Angels Memphis\ Belle Yankee\ Doodle Ball\ of\ Fire Shoo\ Shoo\ Shoo\ Baby);
    my $found = 0;
    for my $expected (@expected_names) {
        $expected =~ s/\\//g;  # Remove escapes
        if ($name eq $expected) {
            $found = 1;
            last;
        }
    }
    ok($found, 'name comes from verified names file');
}

sub test_interactive_accept_suggested {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Simulate pressing Enter to accept suggested name
    my $input = "\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    # Capture output
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'accepting suggested name returns a name');
    like($output, qr/PLANE NAMING/, 'displays naming interface');
    like($output, qr/Suggested name:/, 'shows suggested name');
    like($output, qr/Options:/, 'shows options menu');
}

sub test_interactive_reroll_then_accept {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Simulate: r (reroll), then Enter (accept new suggestion)
    my $input = "r\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    # Capture output
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'reroll then accept returns a name');
    like($output, qr/New suggested name:/, 'shows reroll message');
}

sub test_interactive_verified_then_accept {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Simulate: v (verified historical), then Enter (accept)
    my $input = "v\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    # Capture output
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'verified then accept returns a name');
    like($output, qr/Historical name:/, 'shows historical name message');
}

sub test_interactive_custom_name {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Simulate: c (custom), then enter "My Custom Plane"
    my $input = "c\nMy Custom Plane\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    # Capture output
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    is($name, 'My Custom Plane', 'custom name input works correctly');
    like($output, qr/Enter your custom plane name:/, 'prompts for custom name');
}

sub test_interactive_invalid_then_valid {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        automated => 0,
        generated_names_file => $test->{generated_file},
        verified_names_file => $test->{verified_file}
    );
    
    # Simulate: x (invalid), then Enter (accept suggested)
    my $input = "x\n\n";
    open my $in_fh, '<', \$input;
    local *STDIN = $in_fh;
    
    # Capture output
    my $output = '';
    open my $out_fh, '>', \$output;
    my $old_stdout = select($out_fh);
    
    my $name = $namer->prompt_for_plane_name();
    
    select($old_stdout);
    close $out_fh;
    close $in_fh;
    
    ok(defined $name, 'invalid choice then valid choice works');
    like($output, qr/Invalid choice/, 'shows invalid choice message');
}

sub test_missing_name_files_error {
    my ($test, $report) = @_;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        generated_names_file => '/nonexistent/generated.txt',
        verified_names_file => '/nonexistent/verified.txt'
    );
    
    like(
        dies { $namer->get_random_name() },
        qr/Neither name file found/,
        'dies when both name files are missing'
    );
}

sub test_empty_name_file_error {
    my ($test, $report) = @_;
    
    # Create empty name file
    my $temp_dir = File::Temp->newdir();
    my $empty_file = "$temp_dir/empty.txt";
    open my $fh, '>', $empty_file;
    close $fh;
    
    my $namer = SoloGamer::QotS::PlaneNamer->new(
        generated_names_file => $empty_file,
        verified_names_file => '/nonexistent/verified.txt'
    );
    
    like(
        dies { $namer->get_random_name() },
        qr/No names found in file/,
        'dies when name file is empty'
    );
}

1;