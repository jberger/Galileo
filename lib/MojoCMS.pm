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

  $app->secret( $app->config->{secret} );

  my $schema = $app->db;
  $app->helper( schema => sub { return $schema } );

  $app->helper( 'get_menu' => sub {
    my $self = shift;
    my $name = shift || 'main';
    my $menu = $schema->resultset('Menu')->single({name => $name});
    return $menu->html;
  });

  $app->helper( 'home_page' => sub{ '/pages/home' } );

  $app->helper( 'auth_fail' => sub {
    my $self = shift;
    my $message = shift || "Not Authorized";
    $self->flash( onload_message => $message );
    $self->redirect_to( $self->home_page );
    return 0;
  });

  my $r = $app->routes;

  $r->any( '/' => sub { my $self = shift; $self->redirect_to( $self->home_page ) });
  $r->any( '/pages/:name' )->to('page#show_page');
  $r->post( '/login' )->to('user#login');
  $r->any( '/logout' )->to('user#logout');

  my $if_author = $r->under( sub {
    my $self = shift;

    return $self->auth_fail unless my $name = $self->session->{username};

    my $user = $schema->resultset('User')->single({name => $name});
    return $self->auth_fail unless $user and $user->is_author;

    return 1;
  });

  $if_author->any( '/admin/menu' )->to('editor#edit_menu');
  $if_author->any( '/edit/:name' )->to('editor#edit_page');
  $if_author->websocket( '/store' )->to('editor#ws_update');
}

1;

