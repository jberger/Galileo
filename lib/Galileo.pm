package Galileo;
use Mojo::Base 'Mojolicious';

our $VERSION = '0.027';
$VERSION = eval $VERSION;

use File::Basename 'dirname';
use File::Spec::Functions qw'rel2abs catdir';
use File::ShareDir 'dist_dir';
use Cwd;

has db => sub {
  my $self = shift;
  my $schema_class = $self->config->{db_schema} or die "Unknown DB Schema Class";
  eval "require $schema_class" or die "Could not load Schema Class ($schema_class). $@\n";

  my $schema = $schema_class->connect( 
    @{ $self->config }{ qw/db_dsn db_username db_password db_options/ }
  ) or die "Could not connect to $schema_class using DSN " . $self->config->{db_dsn};

  return $schema;
};

has home_path => sub {
  my $path = $ENV{GALILEO_HOME} || getcwd;
  return File::Spec->rel2abs($path);
};

has config_file => sub {
  my $self = shift;
  return $ENV{GALILEO_CONFIG} if $ENV{GALILEO_CONFIG}; 

  return rel2abs( 'galileo.conf', $self->home_path );
};

sub load_config {
  my $app = shift;

  $app->plugin( Config => { 
    file => $app->config_file,
    default => {
      db_schema  => 'Galileo::DB::Schema',
      db_dsn => 'dbi:SQLite:dbname=' . $app->home->rel_file( 'galileo.db' ),
      db_username => undef,
      db_password => undef,
      db_options => { sqlite_unicode => 1 },
      extra_css => [ '/themes/standard.css' ],
      extra_js => [],
      extra_static_paths => ['static'],
      sanitize => 1,
      secret => '', # default to null (unset) in case I implement an iterative config helper
      upload_path => 'uploads',
    },
  });

  # handle deprecated db_connect
  if ( my $db_connect = delete $app->config->{db_connect} ) {
    warn "### Configuration key db_connect is deprecated ###\n";
    if ( ref $db_connect ) {
      @{ $app->config }{ qw/db_dsn db_username db_password db_options/ } = @$db_connect;
    } else {
      $app->config->{db_dsn} = $db_connect;
    }
  }

  # handle deprecated files key
  if (my $files = $app->config->{files}) {
    warn "### 'files' config key is deprecated, use extra_static_paths ###\n"; 
    push @{ $app->config->{exta_static_paths} }, (ref $files ? @$files : $files);
  }

  # add the files directories to array of static content folders
  # TODO don't repeat
  foreach my $dir ( @{$app->config->{extra_static_paths}} ) {
    # convert relative paths to relative one (to home dir)
    $dir = $app->_to_abs($dir);
    push @{ $app->static->paths }, $dir if -d $dir;
  }

  # normalize and make helper for upload directory
  my $upload;
  if ( my $dir = $app->config->{upload_path} ) {
    $upload = $app->_to_abs($dir);
  }
  if ( -d $upload ) {
    push @{ $app->static->paths }, $upload;
    $app->config->{upload_path} = $upload;
    $app->helper( upload_path => sub { $upload } );
  } else {
    $app->helper( upload_path => sub { 0 } );
  }

  if ( my $secret = $app->config->{secret} ) {
    $app->secret( $secret );
  }
}

sub _to_abs {
  my ($self, $dir) = @_;
  unless ( File::Spec->file_name_is_absolute( $dir ) ) {
    $dir = $self->home->rel_dir( $dir );
  }
  return $dir;
}

sub startup {
  my $app = shift;

  # set home folder
  $app->home->parse( $app->home_path );

  {
    # setup logging path
    # code stolen from Mojolicious.pm
    my $mode = $app->mode;

    $app->log->path($app->home->rel_file("log/$mode.log"))
      if -w $app->home->rel_file('log');
  }

  $app->load_config;

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

  ## Helpers ##

  $app->helper( schema => sub { shift->app->db } );

  $app->helper( 'home_page' => sub{ '/page/home' } );

  $app->helper( 'auth_fail' => sub {
    my $self = shift;
    my $message = shift || "Not Authorized";
    $self->humane_flash( $message );
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

  $app->helper( expire => sub {
    my ($self, $name) = @_;
    $self->flex_memorize->{$name}{expires} = 1;
  });

  $app->plugin( 'Galileo::Plugin::Modal' );

  ## Routing ##

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

  $if_author->any( '/admin/menu' )->to('menu#edit');
  $if_author->any( '/edit/:name' )->to('page#edit');
  $if_author->websocket( '/store/page' )->to('page#store');
  $if_author->websocket( '/store/menu' )->to('menu#store');
  $if_author->websocket( '/files/list' )->to('file#list');

  my $if_admin = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless $self->is_admin;

    return 1;
  });

  $if_admin->any( '/admin/users' )->to('admin#users');
  $if_admin->any( '/admin/pages' )->to('admin#pages');
  $if_admin->any( '/admin/user/:name' )->to('admin#user');
  $if_admin->websocket( '/store/user' )->to('admin#store_user');
  $if_admin->websocket( '/remove/page' )->to('admin#remove_page');

  ## Additional Plugins ##
  $app->plugin('Humane', auto => 0);
  $app->plugin('ConsoleLogger') if $ENV{GALILEO_CONSOLE_LOGGER};
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

=item C<GALILEO_CONSOLE_LOGGER>

Use L<Mojolicious::Plugin::ConsoleLogger> to get additional state information and logger output sent to the browser console.

=back

=head2 The F<galileo> command line application

L<Galileo> installs a command line application, C<galileo>. It inherits from the L<mojo> command and so provides all those commands, but it provides extra functions specifically for use with Galileo.

=head3 setup

 $ galileo setup

This command starts the app in setup mode. It can write a configuration file, and setup or upgrade the database.

This step is required after both installation and upgrading Galileo, because the database page will deploy or upgrade the database used by your Galileo site. It will use the default DBI settings (SQLite) or whatever is setup in the C<GALILEO_CONFIG> configuration file.

Warning: As usual, proper care should be taken when upgrading a database. This mechanism is rather new and while it should be safe, the author makes no promises about anything yet! Backup files and database before upgrading!

Although L<Galileo> does not need to be configured, it is recommended to do so to set your application's secret. The secret can be any string, however stronger is better. You do not need to memorize it or even remember it. This secret protects the cookies employed by Galileo from being tampered with on the client side.

Note that the database deployment tools may emit debugging information unexpectedly to your terminal, especially messages about "overwriting" and some internal "peek" information. These message are harmless, but as yet cannot be suppressed. 

=head3 dump

 $ galileo dump
 $ galileo dump --directory pages -t 

This tool dumps all the pages in your galileo site as markdown files. The directory for exporting to may be specifed with the C<--directory> or C<-d> flag, by default it exports to the current working directory. The title of the page is by default includes as an HTML comment. To include the title as an C<< <h1> >> level directive pass C<--title> or C<-t> without an option. Any other option given to C<--title> will be used as an C<sprintf> format for rendering the title (at the top of the article).

=head1 RUNNING THE APPLICATION

 $ galileo daemon

After the database has been setup, you can run C<galileo daemon> to start the server. 

You may also use L<morbo> (Mojolicious' development server) or L<hypnotoad> (Mojolicious' production server). You may even use any other server that Mojolicious supports, however for full functionality it must support websockets. When doing so you will need to know the full path to the C<galileo> application. A useful recipe might be

 $ hypnotoad `which galileo`

where you may replace C<hypnotoad> with your server of choice.

=head2 Logging

Logging in L<Galileo> is the same as in L<Mojolicious|Mojolicious::Lite/Logging>. Messages will be printed to C<STDERR> unless a directory named F<log> exists in the C<GALILEO_HOME> path, in which case messages will be logged to a file in that directory.

=head2 Extra Static Paths

By default, if Galileo detects a folder named F<static> inside the C<GALILEO_HOME> path, that path is added to the list of folders for serving static files. The name of this folder may be changed in the configuration file via the key C<extra_static_paths>, which expects an array reference of strings representing paths. If any path is relative it will be relative to C<GALILEO_HOME>.

=head2 Upload Path

By default, if Galileo detects a folder named F<uploads> inside the C<GALILEO_HOME> path, that path is used for uploads, specifically user-uploaded images. This path is added to the static files. The name of this folder may be changed in the configuration file via the key C<upload_path>, which expects a string representing the path. If the path is relative it will be relative to C<GALILEO_HOME>.

NOTE: as for this writing, this option doesn't do anything but append to the static files paths. Eventually it will be where uploads go, but NOT YET!

=head1 CUSTOMIZING

The L</config> keys C<extra_css> and C<extra_js> take array references pointing to CSS or Javascript files (respectively) within a L<static directory|/"Static files folder">. As an example, the default C<extra_css> key contains the path to a simple theme css file which adds a gray background and border to the main container.

As yet there are no widgets/plugins as such, however a clever bit of javascript might be able to load something. 

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

=begin html

<p>
  <img src="https://travis-ci.org/jberger/Galileo.png?branch=master" alt="Travis CI build status">
</p>

=end html

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



