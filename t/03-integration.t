#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = '0.001';

use Test2::V0;
use Carp::Always;
use File::Temp qw(tempdir);
use Path::Tiny;
use Carp qw( carp croak );
use English qw( -no_match_vars );  # Avoids regex performance
use FindBin 1.51 qw( $RealBin );
use File::Spec;
my $lib_path;
BEGIN {
    $lib_path = File::Spec->catdir(($RealBin =~ /(.+)/msx)[0], 'lib');
}
use lib "$lib_path";

use Test::Mock::Dist::Zilla;

ok(lives { require Dist::Zilla::App::Command::versions }, 'module loads');

# Create a temporary directory for testing
my $tempdir = tempdir(CLEANUP => 1);
chdir $tempdir or croak "Cannot chdir to $tempdir: $OS_ERROR";

# Create test directory structure
path('lib')->mkpath;
path('bin')->mkpath;
path('script')->mkpath;
path('t/lib')->mkpath;

# Create test files
my @test_files = (
    {
        path => 'lib/Module1.pm',
        content => <<'EOF',
package Module1 0.009;

use strict;
use warnings;

sub test { return 1; }

1;
EOF
        type => 'header',
        old_version => '0.009',
    },
    {
        path => 'lib/Module2.pm',
        content => <<'EOF',
package Module2;

use strict;
use warnings;

our $VERSION = '0.009';

sub test { return 1; }

1;
EOF
        type => 'body',
        old_version => '0.009',
    },
    {
        path => 'bin/script1.pl',
        content => <<'EOF',
#!/usr/bin/env perl

use strict;
use warnings;

our $VERSION = '0.009';

print "Script 1\n";
EOF
        type => 'body',
        old_version => '0.009',
    },
    {
        path => 'script/script2.pl',
        content => <<'EOF',
#!/usr/bin/env perl

use strict;
use warnings;

our $VERSION = '0.009';

print "Script 2\n";
EOF
        type => 'body',
        old_version => '0.009',
    },
    {
        path => 't/lib/TestHelper.pm',
        content => <<'EOF',
package TestHelper;

use strict;
use warnings;

our $VERSION = '0.009';

sub helper { return 1; }

1;
EOF
        type => 'body',
        old_version => '0.009',
    },
);

# Write test files
foreach my $file (@test_files) {
    path($file->{path})->spew_utf8($file->{content});
    ok(-f $file->{path}, "created test file: $file->{path}");
}

# Test: Updating header versions
subtest 'Updating header versions' => sub {
    my $cmd = Dist::Zilla::App::Command::versions->new();

    my $zilla = Test::Mock::Dist::Zilla->new(
        name    => 'Test-Dist',
        version => '0.010',
    );

    my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new(
        set      => 1,
        location => 'header',
    );

    my $args = [];

    # Inject zilla
    $cmd->{zilla} = $zilla;

    # Execute command
    ok(lives { $cmd->execute($opt, $args) }, 'execute with header location succeeds');

    # Check header file was updated
    my $content = path('lib/Module1.pm')->slurp_utf8;
    like($content, qr/package Module1 0[.]010;/msx, 'header version updated to 0.010');
    done_testing();
};

# # Test: Updating body versions with explicit version
# subtest 'Updating body versions with explicit version' => sub {
#     # Reset test file
#     path('lib/Module2.pm')->spew_utf8($test_files[1]->{content});
#
#     my $cmd = Dist::Zilla::App::Command::versions->new();
#
#     my $zilla = Test::Mock::Dist::Zilla->new(
#         name    => 'Test-Dist',
#         version => '0.010',
#     );
#
#     my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new(
#         set      => 1,
#         location => 'body',
#     );
#
#     my $args = ['1.000'];
#
#     $cmd->{zilla} = $zilla;
#
#     ok(lives { $cmd->execute($opt, $args) }, 'execute with explicit version succeeds');
#
#     # Check body files were updated with explicit version
#     my $content = path('lib/Module2.pm')->slurp_utf8;
#     like($content, qr/our \$VERSION = '1\.000';/, 'body version updated to explicit 1.000');
#
#     $content = path('bin/script1.pl')->slurp_utf8;
#     like($content, qr/our \$VERSION = '1\.000';/, 'bin script updated to 1.000');
#
#     $content = path('script/script2.pl')->slurp_utf8;
#     like($content, qr/our \$VERSION = '1\.000';/, 'script updated to 1.000');
#
#     $content = path('t/lib/TestHelper.pm')->slurp_utf8;
#     like($content, qr/our \$VERSION = '1\.000';/, 't/lib module updated to 1.000');
#     done_testing();
# };
#
# # Test: --dir option
# subtest '--dir option' => sub {
#     # Reset test files
#     path('lib/Module2.pm')->spew_utf8($test_files[1]->{content});
#     path('bin/script1.pl')->spew_utf8($test_files[2]->{content});
#
#     my $cmd = Dist::Zilla::App::Command::versions->new();
#
#     my $zilla = Test::Mock::Dist::Zilla->new(
#         name    => 'Test-Dist',
#         version => '0.010',
#     );
#
#     my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new(
#         set      => 1,
#         location => 'body',
#         dir      => ['lib'],
#     );
#
#     my $args = ['2.000'];
#
#     $cmd->{zilla} = $zilla;
#
#     ok(lives { $cmd->execute($opt, $args) }, 'execute with --dir option succeeds');
#
#     # Check only lib files were updated
#     my $content = path('lib/Module2.pm')->slurp_utf8;
#     like($content, qr/our \$VERSION = '2\.000';/, 'lib file updated with --dir lib');
#
#     $content = path('bin/script1.pl')->slurp_utf8;
#     like($content, qr/our \$VERSION = '0\.009';/, 'bin file not updated (not in --dir list)');
#     done_testing();
# };
#
# # Test: Version from zilla
# subtest 'Version from zilla' => sub {
#     # Reset test file
#     path('lib/Module2.pm')->spew_utf8($test_files[1]->{content});
#
#     my $cmd = Dist::Zilla::App::Command::versions->new();
#
#     my $zilla = Test::Mock::Dist::Zilla->new(
#         name    => 'Test-Dist',
#         version => '3.456',
#     );
#
#     my $opt = Test::Mock::Dist::Zilla::App::Command::Options->new(
#         set      => 1,
#         location => 'body',
#         dir      => ['lib'],
#     );
#
#     my $args = [];  # No version argument
#
#     $cmd->{zilla} = $zilla;
#
#     ok(lives { $cmd->execute($opt, $args) }, 'execute with zilla version succeeds');
#
#     # Check file was updated with zilla version
#     my $content = path('lib/Module2.pm')->slurp_utf8;
#     like($content, qr/our \$VERSION = '3\.456';/, 'version from zilla->version used');
#     done_testing();
# };

done_testing();
