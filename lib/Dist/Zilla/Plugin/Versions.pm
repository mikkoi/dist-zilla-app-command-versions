package Dist::Zilla::Plugin::Versions;
## no critic (ControlStructures::ProhibitPostfixControls)

use strict;
use warnings;
use 5.012;  # First Perl version to support syntax "package <name> [<version>]"
use feature qw( say );

# ABSTRACT: Support package version numbers in package name header by providing a place for extra parameters in dist.ini file

our $VERSION = '0.001';

use Carp qw( croak );

use Const::Fast;
use Moose;
with 'Dist::Zilla::Role::Plugin';
use Dist::Zilla::Pragmas;
use namespace::autoclean;
use MooseX::StrictConstructor;

const my @PLUGIN_PARAMETERS => qw( style template );

has style => (
    is   => 'ro',
    isa  => 'Str',
);

has template => (
    is   => 'ro',
    isa  => 'Str',
    # default => sub { return q{} },
);

# TODO If there is no / optional name [Versions]
# Leave plugin_name Versions

around BUILDARGS => sub {
    my $orig = shift;
    my ($class, @arg) = @_;
    my $args = $class->$orig(@arg);
    my %copy = %{ $args };
    my $zilla = delete $copy{zilla};
    my $name  = delete $copy{plugin_name};

    # Parameters for the plugin
    my %params = ( style => 'header', template => q{} );
    foreach my $param ( @PLUGIN_PARAMETERS ) {
        $params{ $param } = delete $copy{ $param } if exists $copy{ $param };
    }
    if( %copy ) {
        my ($plugin_name) = __PACKAGE__ =~ m/::([[:word:]]+)$/msx;
        if( $name ne $plugin_name ) {
            $plugin_name .= ' / ' . $name;
        }
        $zilla->log_fatal( [ 'Plugin [%s] has unknown parameters: %s', $plugin_name, (join q{, }, keys %copy) ] );
    }
    return {
          zilla => $zilla,
          plugin_name => $name,
          %params,
    }
};

no Moose;

sub stringify {
    my ($self) = @_;
    my ($style, $template) = ($self->style, $self->template);
    return "style=$style;template=$template";
}

sub register_prereqs {
    my $self = shift;
    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'develop',
        },
        'Dist::Zilla::App::Command::versions' => 0,

        # TODO also extract list of policies used in file $self->critic_config
    );

    return $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'develop',
        },
        'Versions' => 0,

        # TODO also extract list of policies used in file $self->critic_config
    );
}


use overload
    '.' => \&stringify,
    '""' => \&stringify,
    ;

__PACKAGE__->meta->make_immutable;
1;
