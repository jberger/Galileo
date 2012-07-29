package MojoCMS;

use Mojo::Base 'Mojolicious';

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
    file => 'mojocms.conf',
    default => {
      db_schema  => 'MojoCMS::DB::Schema',
      db_connect => 'dbi:SQLite:dbname=mojocms_sqlite.db',
      secret     => 'MySecret',
    },
  });

  # use content from directories under lib/MojoCMS/
  $app->home->parse(catdir(dirname(__FILE__), 'MojoCMS'));
  $app->static->paths->[0] = $app->home->rel_dir('public');
  $app->renderer->paths->[0] = $app->home->rel_dir('templates');

  # use commands from MojoCMS::Command namespace
  push @{$app->commands->namespaces}, 'MojoCMS::Command';

  $app->secret( $app->config->{secret} );

  $app->helper( schema => sub { shift->app->db } );

  $app->helper( 'home_page' => sub{ '/pages/home' } );

  $app->helper( 'auth_fail' => sub {
    my $self = shift;
    my $message = shift || "Not Authorized";
    $self->flash( onload_message => $message );
    $self->redirect_to( $self->home_page );
    return 0;
  });

  $app->helper( 'is_author' => sub {
    my $self = shift;
    my ($name) = @_;

    my $user = $self->schema->resultset('User')->single({name => $name});
    return undef unless $user;

    return $user->is_author;
  });
  $app->helper( 'is_admin' => sub {
    my $self = shift;
    my ($name) = @_;

    my $user = $self->schema->resultset('User')->single({name => $name});
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
  $r->any( '/pages/:name' )->to('page#show');
  $r->post( '/login' )->to('user#login');
  $r->any( '/logout' )->to('user#logout');

  my $if_author = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless my $name = $self->session->{username};

    my $user = $self->schema->resultset('User')->single({name => $name});
    return $self->auth_fail unless $user and $user->is_author;

    return 1;
  });

  $if_author->any( '/admin/menu' )->to('edit#edit_menu');
  $if_author->any( '/edit/:name' )->to('edit#edit_page');
  $if_author->websocket( '/store/page' )->to('edit#store_page');
  $if_author->websocket( '/store/menu' )->to('edit#store_menu');

  my $if_admin = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless my $name = $self->session->{username};

    my $user = $self->schema->resultset('User')->single({name => $name});
    return $self->auth_fail unless $user and $user->is_admin;

    return 1;
  });

  $if_admin->any( '/admin/users' )->to('admin#users');
  $if_admin->any( '/admin/pages' )->to('admin#pages');
}

1;

