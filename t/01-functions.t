#!/usr/bin/env perl
use strict;
use warnings;
our $VERSION = '0.001';

use Carp qw( carp croak );
use Test2::V0;
use File::Temp qw(tempdir);
use Path::Tiny;
use English qw( -no_match_vars );  # Avoids regex performance

# Change to a temporary directory for testing
my $tempdir = tempdir(CLEANUP => 1);
chdir $tempdir or croak "Cannot chdir to $tempdir: $OS_ERROR";

# Create test directory structure
path('lib')->mkpath;

ok(lives { require Dist::Zilla::App::Command::versions }, 'module loads');

my $cmd = bless {}, 'Dist::Zilla::App::Command::versions';
# *Dist::Zilla::App::Command::versions::log_debug = sub { return };
# *Dist::Zilla::App::Command::versions::log_fatal = sub { return };
package Zilla 0.001 {
    sub log_debug { return; }
    sub log_fatal { return; }
}
my $zilla = bless {}, 'Zilla';
no warnings;
*Dist::Zilla::App::Command::versions::zilla = sub { return $zilla; };
use warnings;

# Test 1: Test --update mode (update existing only)
subtest 'update mode' => sub {
    my $file_with_version = path('lib/HasVersion.pm');
    $file_with_version->spew_utf8(<<'EOF');
package HasVersion;

use strict;
use warnings;

our $VERSION = '0.009';

1;
EOF

    my $file_without_version = path('lib/NoVersion.pm');
    $file_without_version->spew_utf8(<<'EOF');
package NoVersion;

use strict;
use warnings;

1;
EOF

    # Update should only change files with existing versions
    my $changed = $cmd->update_file($file_with_version, '0.010', undef, 'body', 0, 0);
    is($changed, 1, 'file with version was updated');

    my $content = $file_with_version->slurp_utf8;
    like($content, qr/our \$VERSION = '0[.]010';/msx, 'version updated in file with version');

    $changed = $cmd->update_file($file_without_version, '0.010', 'body', 0, 0);
    is($changed, 0, 'file without version was not changed');

    $content = $file_without_version->slurp_utf8;
    unlike($content, qr/VERSION/msx, 'no version added to file without version');
};

# # Test 2: Test --remove mode for body location
# subtest 'remove mode - body' => sub {
#     my $file = path('lib/RemoveBody.pm');
#     $file->spew_utf8(<<'EOF');
# package RemoveBody;
#
# use strict;
# use warnings;
#
# our $VERSION = '0.009';
#
# sub test { return 1; }
#
# 1;
# EOF
#
#     my $changed = $cmd->process_file($file, undef, 'body', 0, 0, 'remove');
#     is($changed, 1, 'version line was removed');
#
#     my $content = $file->slurp_utf8;
#     unlike($content, qr/VERSION/, 'VERSION line removed from file');
#     like($content, qr/package RemoveBody;/, 'package line still present');
#     like($content, qr/sub test/, 'other content still present');
# };
#
# # Test 3: Test --remove mode for header location
# subtest 'remove mode - header' => sub {
#     my $file = path('lib/RemoveHeader.pm');
#     $file->spew_utf8(<<'EOF');
# package RemoveHeader 0.009;
#
# use strict;
# use warnings;
#
# sub test { return 1; }
#
# 1;
# EOF
#
#     my $changed = $cmd->process_file($file, undef, 'header', 0, 0, 'remove');
#     is($changed, 1, 'version was removed from package line');
#
#     my $content = $file->slurp_utf8;
#     like($content, qr/^package RemoveHeader;/m, 'package line without version');
#     unlike($content, qr/package RemoveHeader 0\.009;/, 'version removed from package line');
# };
#
# # Test 4: Test template with simple format
# subtest 'template - simple' => sub {
#     my $file = path('lib/TemplateSimple.pm');
#     $file->spew_utf8(<<'EOF');
# package TemplateSimple;
#
# use strict;
# use warnings;
#
# our $VERSION = '0.009';
#
# 1;
# EOF
#
#     my $template = 'our $VERSION = "<v>";';
#     my $changed = $cmd->process_file($file, '0.010', 'body', 0, 0, 'set', $template);
#     is($changed, 1, 'version updated with template');
#
#     my $content = $file->slurp_utf8;
#     like($content, qr/our \$VERSION = "0\.010";/, 'template applied with double quotes');
#     unlike($content, qr/'0\.010'/, 'old single quote format not present');
# };
#
# # Test 5: Test template with BEGIN block
# subtest 'template - BEGIN block' => sub {
#     my $file = path('lib/TemplateBegin.pm');
#     $file->spew_utf8(<<'EOF');
# package TemplateBegin;
#
# use strict;
# use warnings;
#
# our $VERSION = '0.009';
#
# 1;
# EOF
#
#     my $template = "BEGIN {\n    our \$VERSION = '<v>';\n}";
#     my $changed = $cmd->process_file($file, '0.010', 'body', 0, 0, 'set', $template);
#     is($changed, 1, 'version updated with BEGIN block template');
#
#     my $content = $file->slurp_utf8;
#     like($content, qr/BEGIN \{/, 'BEGIN block present');
#     like($content, qr/our \$VERSION = '0\.010';/, 'version in BEGIN block');
#     like($content, qr/\}/, 'BEGIN block closed');
# };
#
# # Test 6: Test template preserves indentation
# subtest 'template - indentation' => sub {
#     my $file = path('lib/TemplateIndent.pm');
#     $file->spew_utf8(<<'EOF');
# package TemplateIndent;
#
# use strict;
# use warnings;
#
#     our $VERSION = '0.009';
#
# 1;
# EOF
#
#     my $template = 'our $VERSION = q{<v>};';
#     my $changed = $cmd->process_file($file, '0.010', 'body', 0, 0, 'set', $template);
#     is($changed, 1, 'version updated with template');
#
#     my $content = $file->slurp_utf8;
#     like($content, qr/^    our \$VERSION = q\{0\.010\};/m, 'template applied with preserved indentation');
# };
#
# # Test 7: Test remove with different VERSION formats
# subtest 'remove - various formats' => sub {
#     my $file1 = path('lib/RemoveQuoted.pm');
#     $file1->spew_utf8(<<'EOF');
# package RemoveQuoted;
# our $VERSION = "1.234";
# 1;
# EOF
#
#     my $file2 = path('lib/RemoveUnquoted.pm');
#     $file2->spew_utf8(<<'EOF');
# package RemoveUnquoted;
# $VERSION = '0.009';
# 1;
# EOF
#
#     my $changed1 = $cmd->process_file($file1, undef, 'body', 0, 0, 'remove');
#     my $changed2 = $cmd->process_file($file2, undef, 'body', 0, 0, 'remove');
#
#     is($changed1, 1, 'double-quoted version removed');
#     is($changed2, 1, 'single-quoted version without "our" removed');
#
#     unlike($file1->slurp_utf8, qr/VERSION/, 'VERSION removed from file1');
#     unlike($file2->slurp_utf8, qr/VERSION/, 'VERSION removed from file2');
# };
#
# # Test 8: Test update vs set mode
# subtest 'update vs set modes' => sub {
#     # Both should behave the same for existing versions
#     my $file1 = path('lib/ModeSet.pm');
#     $file1->spew_utf8(<<'EOF');
# package ModeSet;
# our $VERSION = '0.009';
# 1;
# EOF
#
#     my $file2 = path('lib/ModeUpdate.pm');
#     $file2->spew_utf8(<<'EOF');
# package ModeUpdate;
# our $VERSION = '0.009';
# 1;
# EOF
#
#     my $changed1 = $cmd->process_file($file1, '0.010', 'body', 0, 0, 'set');
#     my $changed2 = $cmd->process_file($file2, '0.010', 'body', 0, 0, 'update');
#
#     is($changed1, 1, 'set mode updated version');
#     is($changed2, 1, 'update mode updated version');
#
#     my $content1 = $file1->slurp_utf8;
#     my $content2 = $file2->slurp_utf8;
#
#     like($content1, qr/our \$VERSION = '0\.010';/, 'set mode result');
#     like($content2, qr/our \$VERSION = '0\.010';/, 'update mode result');
# };
#
# # Test 9: Test template with header location
# subtest 'template - header location' => sub {
#     my $file = path('lib/HeaderTemplate.pm');
#     $file->spew_utf8(<<'EOF');
# package HeaderTemplate 0.009;
#
# use strict;
# use warnings;
#
# 1;
# EOF
#
#     my $template = 'v<v>';
#     my $changed = $cmd->process_file($file, '0.010', 'header', 0, 0, 'set', $template);
#     is($changed, 1, 'header version updated with template');
#
#     my $content = $file->slurp_utf8;
#     like($content, qr/package HeaderTemplate v0\.010;/, 'template applied to header');
# };
#
# # Test 10: Test remove doesn't affect files without versions
# subtest 'remove - no version' => sub {
#     my $file = path('lib/NoVersionRemove.pm');
#     $file->spew_utf8(<<'EOF');
# package NoVersionRemove;
#
# use strict;
# use warnings;
#
# 1;
# EOF
#
#     my $original = $file->slurp_utf8;
#     my $changed = $cmd->process_file($file, undef, 'body', 0, 0, 'remove');
#
#     is($changed, 0, 'no changes when removing from file without version');
#     is($file->slurp_utf8, $original, 'file content unchanged');
# };
#
done_testing();
