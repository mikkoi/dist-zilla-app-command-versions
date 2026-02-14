package Dist::Zilla::Plugin::PackageDeclarationVersionProvider v0.0.1;
# ABSTRACT: read the version from the module's package declaration header line

use Path::Tiny qw( path );

use Moose;
with(
    'Dist::Zilla::Role::VersionProvider',
);

use Dist::Zilla::Pragmas;

use namespace::autoclean;

sub provide_version {
    my ($self) = @_;

    if (exists $ENV{V}) {
      $self->log_debug([ 'providing version %s', $ENV{V} ]);
      return $ENV{V};
    }

    my $zilla = $self->zilla;
    my $main_module = $zilla->main_module;

    my $version;
    ## no critic (RegularExpressions::ProhibitComplexRegexes)
    my $content = path($main_module->name)->slurp_utf8;
    ($version) = $content =~ m{
        ^(?: \s*package\s+[\w:]+\s+)           # package declaration
        ([v]{0,1}[[:lower:][:upper:][:digit:]._-]+)   # old version (digits, letters, dots, underscores, dashes)
        (?: \s*)                              # semicolon
        }msx;

    $self->log_debug([ 'providing version %s', $version ]);

    return $version;
}

__PACKAGE__->meta->make_immutable;
1;
