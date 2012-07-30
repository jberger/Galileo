package Galileo;
use Mojo::Base 'Mojolicious';

our $VERSION = 0.001;
$VERSION = eval $VERSION;

use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

has db => sub {
  my $self = shift;
  my $schema_class = $self->config->{db_schema} or die "Unknown DB Schema Class";
  eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

  my $db_connect = $self->config->{db_connect} or die "No DBI connection string provided";
  my $schema = $schema_class->connect( $db_connect ) 
    or die "Could not connect to $schema_class using $db_connect";

  return $schema;
};

sub startup {
  my $app = shift;

  $app->plugin( Config => { 
    file => 'galileo.conf',
    default => {
      db_schema  => 'Galileo::DB::Schema',
      db_connect => 'dbi:SQLite:dbname=galileo.db',
      secret     => 'MySecret',
    },
  });

  # use content from directories under lib/Galileo/
  $app->home->parse(catdir(dirname(__FILE__), 'Galileo'));
  $app->static->paths->[0] = $app->home->rel_dir('public');
  $app->renderer->paths->[0] = $app->home->rel_dir('templates');

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

L<Galileo> is a Perl CMS with some modern features. Run C<galileo setup> to setup a database. Afterward the database is ready, you can run C<galileo daemon> or use L<morbo> or L<hypnotoad> to start the server.

=head1 SEE ALSO

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

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Galileo>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



