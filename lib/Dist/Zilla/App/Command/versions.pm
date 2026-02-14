package Dist::Zilla::App::Command::versions 0.001; ## no critic (NamingConventions::Capitalization)
## no critic (ControlStructures::ProhibitPostfixControls)
## no critic (ControlStructures::ProhibitUnlessBlocks)
## no critic (Subroutines::ProhibitExcessComplexity)

# ABSTRACT: Update version strings in module and executable files 

use strict;
use warnings;
use 5.022;

use Carp qw( carp croak );
use English qw( -no_match_vars );  # Avoids regex performance

use Path::Tiny;
use List::Util qw( first );
use Try::Tiny;
use Const::Fast;

use Dist::Zilla::App -command;

=pod

=encoding utf8

=for Pod::Coverage

=for stopwords

=head1 SYNOPSIS

  dzil versions --set --location header 0.010
  dzil versions --set --location body 0.010
  dzil versions --set --location body  # uses version from dist
  dzil versions --set --dir lib --dir bin 1.000

=head1 DESCRIPTION

Updates version strings in Perl modules and scripts. By default, processes files
in lib/, bin/, script/, and t/lib/ directories. Supports two location styles:

=over 4

=item header

Updates package declarations like: C<package Package::Name 0.009;>

=item body

Updates $VERSION assignments like: C<our $VERSION = '0.009';>

=back

=head1 CONFIGURATION

You can configure default values in dist.ini:

  [Dist::Zilla::Plugin::Versions]
  location = body
  dir = lib
  dir = bin

  [Dist::Zilla::Plugin::Versions / lib]
  location = header
  dir = lib
  dir = t/lib

=cut

const my $QR_VERSION_STRING => qr{[[:lower:][:upper:][:digit:]._-]+}msx;

sub abstract { return 'update version strings in distribution files' } ## no critic (NamingConventions::ProhibitAmbiguousNames)

sub usage_desc { return '%c versions --set [%o] [<version>]' }

sub opt_spec {
    return (
        [ 'set', 'set the version, regardless if already present', ],
        [ 'update', 'update version strings where exists', ],
        [ 'remove', 'remove version strings where exists', ],
        [ 'location|l=s', 'where version string is located (header or body)' ],
        [ 'template|t=s', 'what surrounds the version string' ],
        [ 'dir|d=s@', 'directory to process (can be specified multiple times)' ],
        [ 'dry-run|n', 'show what would be changed without making changes' ],
        [ 'verbose|v', 'print detailed information about changes' ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;

    # Validate that --set was provided
    unless ($opt->set || $opt->update || $opt->remove) {
        $self->usage_error('No action specified. Set --set|update|remove.');
    }

    # Version is optional (can come from dist.ini or $zilla->version)
    if (@{ $args } > 1) {
        $self->usage_error('Too many arguments. Specify at most one version number.');
    }

    # Validate version format if provided
    if (@{ $args } == 1) {
        my $version = $args->[0];
        unless ($version =~ (qr/^/msx . $QR_VERSION_STRING . qr/$/msx)) {
        # unless ($version =~ /^[[:lower:][:upper:][:digit:]._-]+$/msx) {
            $self->usage_error("Invalid version format: $version (must contain only digits, letters, dots, underscores, and dashes)");
        }
    }

    return;
}

sub execute {
    my ($self, $opt, $args) = @_;
    use Data::Dumper;

    my $zilla = $self->zilla;

    # Get configuration from dist.ini
    my %config = $self->_get_versions_config($opt);

    # say Dumper( \%config );
    $zilla->log_debug('config: ' . Dumper(\%config) );

    # Determine the version to use
    my $new_version;
    my $zilla_version = try {
        $zilla->version;
    } catch { };
    $zilla->log_debug('zilla_version: ' . ($zilla_version//'[Missing]'));
    if (@{ $args } == 1) {
        # Version specified on command line
        $new_version = $args->[0];
    } elsif ($zilla_version) {
        # Use distribution version
        $new_version = $zilla_version;
        $self->log("Using distribution version: $new_version");
    } else {
        $self->usage_error('No version specified and no version found in distribution');
    }

    # Get location (from command line, config, or error)
    my $location = $opt->location;
    $zilla->log_debug(['location: %s', $location]);
    $location = $config{location} if defined $config{location};
    $zilla->log_debug(['location: %s', $location]);
    if (! $location) {
        $self->usage_error('No location specified. Use --location or configure in dist.ini');
    }

    # Validate location
    if( $location ne 'header' && $location ne 'body' ) {
        $self->usage_error("Invalid location: $location (must be 'header' or 'body')");
    }
    if( $location ne 'header' ) {
        $self->usage_error("Invalid location: $location (Currently only 'header' is supported)");
    }

    # Get template if specified
    my $template = $config{template};
    $zilla->log_debug(['template: %s', $template]);

    # Get directories to process
    my @dirs = @{ $config{dirs} };

    my $dry_run = $opt->dry_run;
    my $verbose = $opt->verbose;

    $self->log("Updating version to: $new_version");
    $self->log("Location: $location");
    $self->log('Directories: ' . (join ', ', @dirs));
    $self->log('Dry run mode') if $dry_run;
    $self->log(q{});

    # Find all .pm and .pl files in specified directories
    my @files;

    for my $dir (@dirs) {
        if (! -d $dir) {
            $self->log("Warning: Directory '$dir' does not exist, skipping");
            next;
        }

        my $path = path($dir);
        my $iter = $path->iterator({ recurse => 1 });

        while (my $file = $iter->()) {
            next unless $file->is_file;
            next unless $file->basename =~ m/[.](?:pm|pl)$/msx;
            push @files, $file;
        }
    }

    if (@files == 0) {
        $zilla->log('No Perl files found in specified directories');
        return;
    }

    my $total_changes = 0;

    for my $file (@files) {
        my $changes = 0;
        if( $opt->set ) {
            $changes = $self->set_file($file, $new_version, $template, $location, $dry_run, $verbose);
        } elsif ( $opt->update ) {
            $changes = $self->update_file($file, $new_version, $template, $location, $dry_run, $verbose);
        } elsif ( $opt->remove ) {
            $changes = $self->remove_file($file, $new_version, $template, $location, $dry_run, $verbose);
        } else {
            $zilla->log_fatal( 'Command should not reach this statement' );
        }
        $total_changes += $changes;
    }

    $self->log(q{});
    if ($dry_run) {
        $self->log("Dry run complete. Would have updated $total_changes file(s).");
    } else {
        $self->log("Updated $total_changes file(s) successfully.");
    }
    return;
}

sub set_file { ## no critic (Subroutines::ProhibitManyArgs)
    my ($self, $file, $new_version, $template, $style, $dry_run, $verbose) = @_;
    my $zilla = $self->zilla;
    $zilla->log_debug( ['set_file(%s, %s, %s, %s, %s, %s)',  $file, $new_version, $template, $style, $dry_run, $verbose] );

    my $content = $file->slurp_utf8;
    my $original = $content;
    my $changed = 0;
    my $is_module = $file.q{} =~ m/[.]pm$/msx;

    if ($is_module && $style eq 'header') {
        # Match: package Package::Name 0.009;
        # Replace with: package Package::Name 0.010;
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*package\s+[\w:]+\s+)              # package declaration
            [v]?[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (\s*;)                                 # semicolon
        }{$1$new_version$2}msxg;

    } elsif ($is_module && $style eq 'body') {
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                            # optional quote
            [[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                            # optional quote
            (\s*;)                              # semicolon
        }{$1'$new_version'$2}msxg;
    } elsif (! $is_module) {
        # Assuming this is a script!
        # 1. Try to find:
        #     our $VERSION = '0.009';
        #   - if found, change that
        # 2. If not found:
        #   - Try to find:
        #     # ABSTRACT:
        #   - if found, put version on next line.
        # 3. If not found:
        #   - Try to find:
        #     use strict / use warnings / use <perl version>
        #   - if found, put version on next line.
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                            # optional quote
            [[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                            # optional quote
            (\s*;)                              # semicolon
        }{$1'$new_version'$2}msxg;
    } else {
        $self->usage_error('Control should not reach this statement');
    }

    if ($changed) {
        $self->_change_file($file, $original, $content, $dry_run, $verbose);
        return 1;
    }

    return 0;
}

sub update_file { ## no critic (Subroutines::ProhibitManyArgs)
    my ($self, $file, $new_version, $template, $style, $dry_run, $verbose) = @_;
    my $zilla = $self->zilla;
    $zilla->log_debug( ['update_file(%s, %s, %s, %s, %s, %s)',  $file, $new_version, $template, $style, $dry_run, $verbose] );

    my $content = $file->slurp_utf8;
    my $original = $content;
    my $changed = 0;
    my $is_module = $file.q{} =~ m/[.]pm$/msx;
    $zilla->log_debug( ['is_module: %s)',  $is_module] );

    if ($is_module && $style eq 'header') {
        # Match: "package Package::Name 0.009"
        # Replace with: package Package::Name 0.010;
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*package\s+[\w:]+\s+)                   # package declaration
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (\s*)                                       # no semicolon, new syntax allows a block after version
        }{$1$new_version$2}msxg;
    } elsif ($is_module && $style eq 'body') {
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                            # optional quote
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                            # optional quote
            (\s*;)                              # semicolon
        }{$1'$new_version'$2}msxg;
    } elsif (! $is_module ) {
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                            # optional quote
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                            # optional quote
            (\s*;)                              # semicolon
        }{$1'$new_version'$2}msxg;
    } else {
        $self->usage_error('Control should not reach this statement');
    }

    if ($changed) {
        $self->_change_file($file, $original, $content, $dry_run, $verbose);
        return 1;
    }

    return 0;
}

sub remove_file { ## no critic (Subroutines::ProhibitManyArgs)
    my ($self, $file, $new_version, $template, $style, $dry_run, $verbose) = @_;

    my $content = $file->slurp_utf8;
    my $original = $content;
    my $changed = 0;
    my $is_module = $file.q{} =~ m/[.]pm$/msx;

    if ($is_module && $style eq 'header') {
        # Match: "package Package::Name 0.009"
        # Replace with: package Package::Name 0.010;
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*package\s+[\w:]+\s+)           # package declaration
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (\s*)                               # no semicolon, new syntax allows a block after version
        }{$1}msxg;

    } elsif ($is_module && $style eq 'body') {
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                           # optional quote
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                           # optional quote
            (\s*;\s*[\r])                       # semicolon and line feed
        }{}msxg;
    } elsif (! $is_module ) {
        # Match: our $VERSION = '0.009';
        # Also handles: our $VERSION = "0.009";
        #               our $VERSION = 0.009;
        #               $VERSION = '0.009';
        # Updated regex to handle new version format
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $changed = $content =~ s{
            ^(\s*(?:our\s+)?\$VERSION\s*=\s*)   # $VERSION assignment
            (?:['"])?                           # optional quote
            [v]{0,1}[[:lower:][:upper:][:digit:]._-]+   # old version (digits, letters, dots, underscores, dashes)
            (?:['"])?                           # optional quote
            (\s*;\s*[\r])                       # semicolon and line feed
        }{$1'$new_version'$2}msxg;
    } else {
        $self->usage_error('Control should not reach this statement');
    }

    if ($changed) {
        $self->_change_file($file, $original, $content, $dry_run, $verbose);
        return 1;
    }

    return 0;
}

sub _change_file { ## no critic (Subroutines::ProhibitManyArgs)
    my ($self, $file, $original, $content, $dry_run, $verbose) = @_;
    my $zilla = $self->zilla;
    # $zilla->log_debug( ['set_file(%s, %s, %s, %s, %s)',  $file, $original, $content, $dry_run, $verbose] );
    if ($verbose || $dry_run) {
        $self->log("Processing: $file");

        if ($verbose) {
            # Show the actual changes
            my @old_lines = split qr/\n/msx, $original;
            my @new_lines = split qr/\n/msx, $content;

            for my $i (0 .. $#old_lines) {
                if ($old_lines[$i] ne $new_lines[$i]) {
                    $self->log("  - $old_lines[$i]");
                    $self->log("  + $new_lines[$i]");
                }
            }
        }
    }

    if (! $dry_run) {
        $file->spew_utf8($content);
        $self->log("Updated: $file") unless $verbose;
    }

    return;
}

sub _get_versions_config {
    my ($self, $opt) = @_;
    my $zilla = $self->zilla;

    $zilla->log_debug(['_get_versions_config called']);

    my %config;
    my @dirs;
    my $location;

    # 1. Start with default directories
    @dirs = qw(lib bin script t/lib);
    $zilla->log_debug(['1. Default dirs: ' . (join ', ', @dirs)]);
    my $plugins = $zilla->{'plugins'};

    # 2. Get config from [Dist::Zilla::Plugin::Versions] (general config)
    my @all_versions_plugins = grep { $_->isa('Dist::Zilla::Plugin::Versions') } @{ $plugins };
    my %dir_plugins = map { $_->plugin_name => $_ } @all_versions_plugins;
    $zilla->log_debug('all_versions_plugins:');
    foreach my $plg (@all_versions_plugins) {
        $zilla->log_debug(['    plugin_name: %s', $plg->plugin_name]);
        $zilla->log_debug(['    plugin: %s', $plg]);
        $config{location} = $plg->style;
        $config{template} = $plg->template;
    }

    # my $plain_plugin = first {
    #     $_->isa('Dist::Zilla::Plugin')
    #     && ref($_) =~ /::Versions$/
    #     && $_->plugin_name eq 'Versions'
    # } @{ $zilla->{'plugins'} };
    #
    # if ($plain_plugin) {
    #     $zilla->log_debug(['2. Found general [Dist::Zilla::Plugin::Versions] config']);
    #     if ($plain_plugin->{'location'}) {
    #         $location = $plain_plugin->{'location'};
    #         $zilla->log_debug(["   location: $location"]);
    #     }
    #     if ($plain_plugin->{'dir'}) {
    #         if (ref($plain_plugin->{'dir'}) eq 'ARRAY') {
    #             @dirs = @{ $plain_plugin->{'dir'} };
    #         } else {
    #             @dirs = ( $plain_plugin->{'dir'} );
    #         }
    #         $zilla->log_debug(['   dirs: ' . join(', ', @dirs)]);
    #     }
    # }

    # # 3. Get config from [Dist::Zilla::Plugin::Versions / SomeName] (specific config)
    # my $named_plugin = first {
    #     $_->isa('Dist::Zilla::Plugin')
    #     && ref($_) =~ /::Versions$/
    #     && $_->plugin_name ne 'Versions'
    # } @{ $zilla->{'plugins'} };
    #
    # if ($named_plugin) {
    #     $zilla->log_debug(['3. Found named [Dist::Zilla::Plugin::Versions / ' . $named_plugin->plugin_name . '] config']);
    #     if ($named_plugin->{'location'}) {
    #         $location = $named_plugin->{'location'};
    #         $zilla->log_debug(["   location: $location"]);
    #     }
    #     if ($named_plugin->{'dir'}) {
    #         if (ref($named_plugin->{'dir'}) eq 'ARRAY') {
    #             @dirs = @{ $named_plugin->{'dir'} };
    #         } else {
    #             @dirs = ( $named_plugin->{'dir'} );
    #         }
    #         $zilla->log_debug(['   dirs: ' . (join ', ', @dirs)]);
    #     }
    # }

    # 4. Command line options override everything
    if ($opt->location) {
        $location = $opt->location;
        $zilla->log_debug(["4. Command line location: $location"]);
    }
    if ($opt->dir) {
        @dirs = @{ $opt->dir };
        $zilla->log_debug(['4. Command line dirs: ' . (join ', ', @dirs)]);
    }

    $config{location} = $location if defined $location;
    $config{dirs} = \@dirs;

    $zilla->log_debug(['Final location: ' . ($location // 'undef')]);
    $zilla->log_debug(['Final dirs: ' . (join ', ', @dirs)]);

    return %config;
}

1;

__END__

=head1 EXAMPLES

  # Update version in package declarations (explicit version)
  dzil versions --set --location header 0.010

  # Update version in $VERSION assignments (explicit version)
  dzil versions --set --location body 0.010

  # Use version from dist.ini or $zilla->version
  dzil versions --set --location body

  # Process only specific directories
  dzil versions --set --location header --dir lib --dir bin 1.000

  # Preview changes without modifying files
  dzil versions --set --location body 0.010 --dry-run

  # Show detailed diff of changes
  dzil versions --set --location header 0.010 --verbose

=head1 VERSION SOURCES

The command determines the version to use in the following priority order:

1. Version specified on command line (e.g., C<dzil versions --set --location body 0.010>)
2. Distribution version from C<$zilla-E<gt>version>
3. Version from C<version> item in dist.ini
4. Error if none of the above are available

=head1 CONFIGURATION IN dist.ini

You can set default values in your dist.ini file:

  ; General configuration for all uses
  [Dist::Zilla::Plugin::Versions]
  location = body
  dir = lib
  dir = t/lib

  ; Named configuration overrides general, named after any directory
  [Dist::Zilla::Plugin::Versions / bin]
  location = body
  dir = lib

Command line options always override dist.ini configuration.
