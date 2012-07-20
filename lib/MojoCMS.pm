package MojoCMS;

use Mojo::Base 'Mojolicious';

use Mojo::ByteStream;

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

  $app->secret( $app->config->{secret} );

  my $schema = do {
    my $schema_class = $app->config->{db_schema} or die "Unknown DB Schema Class";
    eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

    my $db_connect = $app->config->{db_connect} or die "No DBI connection string provided";
    my $schema = $schema_class->connect( $db_connect ) 
      or die "Could not connect to $schema_class using $db_connect";

    $schema;
  };

  $app->helper( schema => sub { return $schema } );

  $app->helper( user_menu => sub {
    my $self = shift;
    my $user = $self->session->{username};

    my $url = $self->tx->req->url;
    my $html;
    if ($user) {
      my $edit_this_page = 
        $url =~ s{/pages/}{/edit/} 
        ? qq{<li><a href="$url">Edit This Page</a></li>} 
        : '';
      $html = <<USER;
<div class="well" style="padding: 8px 0;">
  <ul class="nav nav-list">
    <li class="nav-header">Hello $user</li>
    $edit_this_page
    <li><a href="/admin/menu">Setup Nav Menu</a></li>
    <li><a href="/logout">Log Out</a></li>
  </ul>
</div>
USER
    } else {
      $html = <<ANON;
<form class="well" method="post" action="/login">
  <input type="hidden" name="from" value="$url">
  <input type="text" class="input-small" placeholder="Username" name="username">
  <input type="password" class="input-small" placeholder="Password" name="password">
  <input type="submit" class="btn" value="Sign In">
</form>
ANON
    }
    return Mojo::ByteStream->new( $html );
  });

  $app->helper( 'get_menu' => sub {
    my $self = shift;
    my $name = shift || 'main';
    my $menu = $schema->resultset('Menu')->single({name => $name});
    return $menu->html;
  });

  $app->helper( 'home_page' => sub{ '/pages/home' } );

  my $r = $app->routes;

  $r->any( '/' => sub { my $self = shift; $self->redirect_to( $self->home_page ) });
  $r->any( '/pages/:name' )->to('page#show_page');
  $r->post( '/login' )->to('user#login');
  $r->any( '/logout' )->to('user#logout');

  my $if_author = $r->under( sub {
    my $self = shift;
    my $fail = sub {
      $self->flash( onload_message => "Not Authorized" );
      $self->redirect_to( $self->home_page );
      return 0;
    };

    return $fail->() unless my $name = $self->session->{username};

    my $user = $schema->resultset('User')->single({name => $name});
    return $fail->() unless $user and $user->is_author;

    return 1;
  });

  $if_author->any( '/admin/menu' )->to('editor#edit_menu');
  $if_author->any( '/edit/:name' )->to('editor#edit_page');
  $if_author->websocket( '/store' )->to('editor#ws_update');
}

1;

