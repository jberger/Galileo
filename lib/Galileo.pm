package Galileo;
use Mojo::Base 'Mojolicious';

our $VERSION = 0.006;
$VERSION = eval $VERSION;

use File::Basename 'dirname';
use File::Spec::Functions qw'rel2abs catdir';
use File::ShareDir 'dist_dir';
use Cwd;

has db => sub {
  my $self = shift;
  my $schema_class = $self->config->{db_schema} or die "Unknown DB Schema Class";
  eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

  my $db_connect = $self->config->{db_connect} or die "No DBI connection string provided";
  my @db_connect = ref $db_connect ? @$db_connect : ( $db_connect );

  my $schema = $schema_class->connect( @db_connect ) 
    or die "Could not connect to $schema_class using $db_connect[0]";

  return $schema;
};

has home_path => $ENV{GALILEO_HOME} || getcwd;

has config_file => sub {
  my $self = shift;
  return $ENV{GALILEO_CONFIG} if $ENV{GALILEO_CONFIG}; 

  return rel2abs( 'galileo.conf', $self->home_path );
};

sub startup {
  my $app = shift;

  {
    $app->home->parse( $app->home_path );

    # mock code from Mojolicious.pm
    my $mode = $app->mode;

    $app->log->path($app->home->rel_file("log/$mode.log"))
      if -w $app->home->rel_file('log');
  }

  $app->plugin( Config => { 
    file => $app->config_file,
    default => {
      db_schema  => 'Galileo::DB::Schema',
      db_connect => [
        'dbi:SQLite:dbname=' . $app->home->rel_file( 'galileo.db' ),
        undef,
        undef,
        { sqlite_unicode => 1 },
      ],
      secret => 'MySecret',
    },
  });

  {
    # use content from directories under lib/Galileo/files or using File::ShareDir
    my $lib_base = catdir(dirname(rel2abs(__FILE__)), 'Galileo', 'files');

    my $public = catdir($lib_base, 'public');
    $app->static->paths->[0] = -d $public ? $public : catdir(dist_dir('Galileo'), 'public');

    my $templates = catdir($lib_base, 'templates');
    $app->renderer->paths->[0] = -d $templates ? $templates : catdir(dist_dir('Galileo'), 'templates');
  }

  # use commands from Galileo::Command namespace
  push @{$app->commands->namespaces}, 'Galileo::Command';

  $app->secret( $app->config->{secret} );

  $app->helper( schema => sub { shift->app->db } );

  $app->helper( 'home_page' => sub{ '/page/home' } );

  $app->helper( 'auth_fail' => sub {
    my $self = shift;
    my $message = shift || "Not Authorized";
    $self->flash( onload_message => $message );
    $self->redirect_to( $self->home_page );
    return 0;
  });

  $app->helper( 'get_user' => sub {
    my ($self, $name) = @_;
    unless ($name) {
      $name = $self->session->{username};
    }
    return undef unless $name;
    return $self->schema->resultset('User')->single({name => $name});
  });

  $app->helper( 'is_author' => sub {
    my $self = shift;
    my $user = $self->get_user(@_);
    return undef unless $user;
    return $user->is_author;
  });
  $app->helper( 'is_admin' => sub {
    my $self = shift;
    my $user = $self->get_user(@_);
    return undef unless $user;
    return $user->is_admin;
  });

  my %mem;
  $app->helper(
    flex_memorize => sub {
      shift;
      return \%mem unless @_;

      return '' unless ref(my $cb = pop) eq 'CODE';
      my ($name, $args)
        = ref $_[0] eq 'HASH' ? (undef, shift) : (shift, shift || {});

      # Default name
      $name ||= join '', map { $_ || '' } (caller(1))[0 .. 3];

      # Expire old results
      my $expires;
      if (exists $mem{$name}) {
        $expires = $mem{$name}{expires};
        delete $mem{$name}
          if $expires > 0 && $mem{$name}{expires} < time;
      } else {
        $expires = $args->{expires} || 0;
      }

      # Memorized result
      return $mem{$name}{content} if exists $mem{$name};

      # Memorize new result
      $mem{$name}{expires} = $expires;
      return $mem{$name}{content} = $cb->();
    }
  );

  my $r = $app->routes;

  $r->any( '/' => sub { my $self = shift; $self->redirect_to( $self->home_page ) });
  $r->any( '/page/:name' )->to('page#show');
  $r->post( '/login' )->to('user#login');
  $r->any( '/logout' )->to('user#logout');

  my $if_author = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless $self->is_author;

    return 1;
  });

  $if_author->any( '/admin/menu' )->to('edit#edit_menu');
  $if_author->any( '/edit/:name' )->to('edit#edit_page');
  $if_author->websocket( '/store/page' )->to('edit#store_page');
  $if_author->websocket( '/store/menu' )->to('edit#store_menu');

  my $if_admin = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless $self->is_admin;

    return 1;
  });

  $if_admin->any( '/admin/users' )->to('admin#users');
  $if_admin->any( '/admin/pages' )->to('admin#pages');
  $if_admin->any( '/admin/user/:name' )->to('admin#user');
  $if_admin->websocket( '/store/user' )->to('admin#store_user');
}

1;

__END__

=head1 NAME

Galileo - A simple modern CMS built on Mojolicious

=head1 SYNOPSIS

 $ galileo setup
 $ galileo daemon

=head1 DESCRIPTION

L<Galileo> is a Perl CMS with some modern features. It uses client-side markdown rendering and websockets for saving page data without reloading. L<Galileo> relies on many other great open-source projects, see more in the L</"TECHNOLOGIES USED"> section.

This release is very young, don't expect anything not to break, for now. Bug reports very welcome.

=head1 INSTALLATION

L<Galileo> uses well-tested and widely-used CPAN modules, so installation should be as simple as

    $ cpanm Galileo

when using L<App::cpanminus>. Of course you can use your favorite CPAN client or install manually by cloning the L</"SOURCE REPOSITORY">.

=head1 SETUP

=head2 Environment

Although most of L<Galileo> is controlled by a configuration file, a few properties must be set before that file can be read. These properties are controlled by the following environment variables.

=over 

=item C<GALILEO_HOME>

This is the directory where L<Galileo> expects additional files. These include the configuration file and log files. The default value is the current working directory (C<cwd>).

=item C<GALILEO_CONFIG>

This is the full path to a configuration file. The default is a file named F<galileo.conf> in the C<GALILEO_HOME> path, however this file need not actually exist, defaults may be used instead. This file need not be written by hand, it may be generated by the C<galileo config> command.

=back

=head2 The F<galileo> command line application

L<Galileo> installs a command line application, C<galileo>. It inherits from the L<mojo> command, but it provides extra functions specifically for use with Galileo.

=head3 config

 $ galileo config [options]

This command writes a configuration file in your C<GALILEO_HOME> path. It uses the preset defaults for all values, except that it prompts for a secret. This can be any string, however stronger is better. You do not need to memorize it or remember it. This secret protects the cookies employed by Galileo from being tampered with on the client side.

L<Galileo> does not need to be configured, however it is recommended to do so to set your application's secret. 

The C<--force> option may be passed to overwrite any configuration file in the current working directory. The default is to die if such a configuration file is found.

=head3 setup

 $ galileo setup

This step is required. Run C<galileo setup> to setup a database. It will use the default DBI settings (SQLite) or whatever is setup in the C<GALILEO_CONFIG> configuration file.

=head1 RUNNING THE APPLICATION

 $ galileo daemon

After the database is has been setup, you can run C<galileo daemon> to start the server. 

You may also use L<morbo> (Mojolicious' development server) or L<hypnotoad> (Mojolicious' production server). You may even use any other server that Mojolicious supports, however for full functionality it must support websockets. When doing so you will need to know the full path to the C<galileo> application. A useful recipe might be

 $ hypnotoad `which galileo`

where you may replace C<hypnotoad> with your server of choice.

=head2 Logging

Logging in L<Galileo> is the same as in L<Mojolicious|Mojolicious::Lite/Logging>. Messages will be printed to C<STDERR> unless a directory named F<log> exists in the C<GALILEO_HOME> path, in which case messages will be logged to a file in that directory.

=head1 TECHNOLOGIES USED

=over

=item * 

L<Mojolicious|http://mojolicio.us> - a next generation web framework for the Perl programming language

=item * 

L<DBIx::Class|http://www.dbix-class.org/> - an extensible and flexible Object/Relational Mapper written in Perl

=item * 

L<PageDown|http://code.google.com/p/pagedown/> (Markdown engine) - the version of Attacklab's Showdown and WMD as used on Stack Overflow and the other Stack Exchange sites

=item * 

L<Bootstrap|http://twitter.github.com/bootstrap> - the beautiful CSS/JS library from Twitter

=item * 

L<jQuery|http://jquery.com/> - because everything uses jQuery

=item * 

L<HumaneJS|http://wavded.github.com/humane-js/> - A simple, modern, browser notification system

=back

=head1 SEE ALSO

=over

=item *

L<Contenticious> - File-based Markdown website application

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Galileo>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



