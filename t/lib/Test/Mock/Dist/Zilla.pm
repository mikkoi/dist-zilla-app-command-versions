package Test::Mock::Dist::Zilla 0.001;

use strict;
use warnings;
use 5.022;

=head1 NAME

Test::Mock::Dist::Zilla - Mock Dist::Zilla objects for testing

=head1 SYNOPSIS

  use Test::Mock::Dist::Zilla;
  
  my $zilla = Test::Mock::Dist::Zilla->new(
      name    => 'My-Dist',
      version => '0.010',
  );
  
  my $plugin = Test::Mock::Dist::Zilla::Plugin->new(
      plugin_name => 'Versions',
      location    => 'body',
  );

=head1 DESCRIPTION

This module provides mock objects that simulate Dist::Zilla and its
plugins for testing purposes, without requiring Dist::Zilla to be installed.

=cut

# Mock Dist::Zilla class
package Test::Mock::Dist::Zilla;

sub new {
    my ($class, %args) = @_;
    
    my $self = {
        name            => $args{name} // 'Test-Dist',
        version         => $args{version},
        abstract        => $args{abstract} // 'A test distribution',
        authors         => $args{authors} // ['Test Author <test@example.com>'],
        license         => $args{license},
        plugins         => $args{plugins} // [],
        files           => $args{files} // [],
        _log_messages   => [],
        _log_debug_messages => [],
    };
    
    return bless $self, $class;
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub version {
    my $self = shift;
    if (@_) {
        $self->{version} = shift;
    }
    return $self->{version};
}

sub abstract {
    my $self = shift;
    return $self->{abstract};
}

sub authors {
    my $self = shift;
    return $self->{authors};
}

sub license {
    my $self = shift;
    return $self->{license};
}

sub plugins {
    my $self = shift;
    return $self->{plugins};
}

sub files {
    my $self = shift;
    return $self->{files};
}

sub log {
    my ($self, $message) = @_;
    push @{ $self->{_log_messages} }, $message;
    # Optionally print for debugging
    # print "LOG: $message\n";
    return;
}

sub log_debug {
    my ($self, $message) = @_;
    push @{ $self->{_log_debug_messages} }, ref($message) eq 'ARRAY' ? $message->[0] : $message;
    # Optionally print for debugging
    # print "DEBUG: " . (ref($message) eq 'ARRAY' ? $message->[0] : $message) . "\n";
    return;
}

sub log_fatal {
    my ($self, $message) = @_;
    die $message;
}

sub get_log_messages {
    my $self = shift;
    return @{ $self->{_log_messages} };
}

sub get_log_debug_messages {
    my $self = shift;
    return @{ $self->{_log_debug_messages} };
}

sub clear_log {
    my $self = shift;
    $self->{_log_messages} = [];
    $self->{_log_debug_messages} = [];
    return;
}

# Mock Dist::Zilla::Plugin base class
package Test::Mock::Dist::Zilla::Plugin;

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub plugin_name {
    my $self = shift;
    return $self->{plugin_name} // 'MockPlugin';
}

sub isa {
    my ($self, $class) = @_;
    return 1 if $class eq 'Dist::Zilla::Plugin';
    return 1 if $class eq 'Test::Mock::Dist::Zilla::Plugin';
    return UNIVERSAL::isa($self, $class);
}

sub does {
    my ($self, $role) = @_;
    return 1 if $role eq 'Dist::Zilla::Role::VersionProvider';
    return 0;
}

# Mock Dist::Zilla::App::Command base class
package Test::Mock::Dist::Zilla::App::Command;

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub zilla {
    my $self = shift;
    if (@_) {
        $self->{zilla} = shift;
    }
    return $self->{zilla};
}

sub log {
    my ($self, $message) = @_;
    if ($self->{zilla}) {
        $self->{zilla}->log($message);
    }
    return;
}

sub log_debug {
    my ($self, $message) = @_;
    if ($self->{zilla}) {
        $self->{zilla}->log_debug($message);
    }
    return;
}

sub log_fatal {
    my ($self, $message) = @_;
    if ($self->{zilla}) {
        $self->{zilla}->log_fatal($message);
    } else {
        die $message;
    }
}

sub usage_error {
    my ($self, $message) = @_;
    die "Usage error: $message\n";
}

# Mock options object
package Test::Mock::Dist::Zilla::App::Command::Options;

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub set {
    my $self = shift;
    return $self->{set} // 0;
}

sub location {
    my $self = shift;
    return $self->{location};
}

sub dir {
    my $self = shift;
    return $self->{dir};
}

sub dry_run {
    my $self = shift;
    return $self->{dry_run} // 0;
}

sub verbose {
    my $self = shift;
    return $self->{verbose} // 0;
}

=head1 HELPER FUNCTIONS

=head2 create_mock_zilla

Creates a fully configured mock Dist::Zilla object with plugins.

  my $zilla = Test::Mock::Dist::Zilla->create_mock_zilla(
      name    => 'My-Dist',
      version => '0.010',
      plugins => [
          { plugin_name => 'Versions', location => 'body' },
      ],
  );

=cut

package Test::Mock::Dist::Zilla;

sub create_mock_zilla {
    my ($class, %args) = @_;
    
    my @plugin_objs;
    if ($args{plugins}) {
        foreach my $plugin_spec (@{ $args{plugins} }) {
            my $plugin = Test::Mock::Dist::Zilla::Plugin->new(%$plugin_spec);
            push @plugin_objs, $plugin;
        }
    }
    
    $args{plugins} = \@plugin_objs;
    
    return $class->new(%args);
}

=head1 USAGE EXAMPLES

=head2 Basic Mock

  use Test::Mock::Dist::Zilla;
  
  my $zilla = Test::Mock::Dist::Zilla->new(
      name    => 'Test-Distribution',
      version => '1.000',
  );
  
  is($zilla->name, 'Test-Distribution');
  is($zilla->version, '1.000');

=head2 Mock with Plugins

  my $zilla = Test::Mock::Dist::Zilla->create_mock_zilla(
      name    => 'My-Dist',
      version => '0.010',
      plugins => [
          { 
              plugin_name => 'Versions',
              location    => 'body',
              dir         => ['lib', 'bin'],
          },
      ],
  );
  
  my @plugins = @{ $zilla->plugins };
  is($plugins[0]->plugin_name, 'Versions');

=head2 Testing Log Output

  my $zilla = Test::Mock::Dist::Zilla->new(name => 'Test');
  
  $zilla->log('Test message');
  $zilla->log_debug(['Debug message']);
  
  my @messages = $zilla->get_log_messages;
  is($messages[0], 'Test message');
  
  my @debug = $zilla->get_log_debug_messages;
  is($debug[0], 'Debug message');

=cut

1;

__END__

=head1 AUTHOR

Your Name <your.email@example.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Your Name.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
