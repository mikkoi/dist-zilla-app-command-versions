#!/usr/bin/env perl

use strict;
use warnings;
use Test2::V0;
use File::Temp qw(tempdir);
use Path::Tiny;
use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Mock::Dist::Zilla;
use Dist::Zilla::App::Command::versions;

# Create a temporary directory for testing
my $tempdir = tempdir(CLEANUP => 1);
chdir $tempdir or die "Cannot chdir to $tempdir: $!";

# Create test directory structure
path('lib')->mkpath;

# Test 1-4: Test _get_versions_config with default values
{
    my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
    
    # Mock zilla object with no plugins
    my $zilla = Test::Mock::Dist::Zilla->new(
        name    => 'Test-Dist',
        plugins => [],
    );
    
    # Mock opt object with no options
    my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new();
    
    my %config = $cmd->_get_versions_config($opt);
    
    is($config{location}, undef, 'no default location without config');
    ok(defined $config{dirs}, 'dirs are defined');
    is(ref($config{dirs}), 'ARRAY', 'dirs is an array reference');
    is($config{dirs}, [qw(lib bin script t/lib)], 'default dirs are correct');
}

# Test 5-6: Test _get_versions_config with plugin config
{
    my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
    
    my $zilla = Test::Mock::Dist::Zilla->create_mock_zilla(
        name    => 'Test-Dist',
        plugins => [
            {
                plugin_name => 'Versions',
                location    => 'body',
                dir         => ['lib', 'bin'],
            },
        ],
    );
    
    my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new();
    
    my %config = $cmd->_get_versions_config($opt);
    
    is($config{location}, 'body', 'location from plugin config');
    is($config{dirs}, ['lib', 'bin'], 'dirs from plugin config');
}

# Test 7-8: Test command line override
{
    my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
    
    my $zilla = Test::Mock::Dist::Zilla->create_mock_zilla(
        name    => 'Test-Dist',
        plugins => [
            {
                plugin_name => 'Versions',
                location    => 'body',
                dir         => ['lib', 'bin'],
            },
        ],
    );
    
    my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new(
        location => 'header',
        dir      => ['lib'],
    );
    
    my %config = $cmd->_get_versions_config($opt);
    
    is($config{location}, 'header', 'command line overrides plugin location');
    is($config{dirs}, ['lib'], 'command line overrides plugin dirs');
}

# Test 9-10: Test named plugin config
{
    my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
    
    my $zilla = Test::Mock::Dist::Zilla->create_mock_zilla(
        name    => 'Test-Dist',
        plugins => [
            {
                plugin_name => 'Versions',
                location    => 'body',
                dir         => ['lib', 'bin'],
            },
            {
                plugin_name => 'MyConfig',
                location    => 'header',
                dir         => ['lib'],
            },
        ],
    );
    
    my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new();
    
    my %config = $cmd->_get_versions_config($opt);
    
    is($config{location}, 'header', 'named plugin overrides general plugin location');
    is($config{dirs}, ['lib'], 'named plugin overrides general plugin dirs');
}

# Test 11: Test _get_version_from_dist_ini
{
    my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
    
    my $zilla = Test::Mock::Dist::Zilla->new(
        name    => 'Test-Dist',
        version => '1.234',
    );
    
    my $version = $cmd->_get_version_from_dist_ini($zilla);
    is($version, '1.234', '_get_version_from_dist_ini returns zilla version');
}

# Test 12-14: Test log methods
{
    my $zilla = Test::Mock::Dist::Zilla->new(name => 'Test-Dist');
    
    $zilla->log('Test message');
    $zilla->log_debug(['Debug message']);
    
    my @messages = $zilla->get_log_messages;
    is($messages[0], 'Test message', 'log message captured');
    
    my @debug = $zilla->get_log_debug_messages;
    is($debug[0], 'Debug message', 'debug message captured');
    
    $zilla->clear_log;
    @messages = $zilla->get_log_messages;
    is(scalar @messages, 0, 'log cleared');
}

done_testing();
