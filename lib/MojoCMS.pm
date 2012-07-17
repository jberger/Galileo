package MojoCMS;

use Mojo::Base 'Mojolicious';

use Mojo::ByteStream;
use Mojo::JSON;
my $json = Mojo::JSON->new();

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

  $app->helper( 'db_connect' => sub {
    my $self = shift;
    my $schema_class = $app->config->{db_schema} or die "Unknown DB Schema Class";
    eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

    my $db_connect = $app->config->{db_connect} or die "No DBI connection string provided";
    my $schema = $schema_class->connect( $db_connect ) 
      or die "Could not connect to $schema_class using $db_connect";

    return $schema;
  });

  my $schema = $app->db_connect;

  $app->helper( user_menu => sub {
    my $self = shift;
    my $user = $self->session->{username};
    my $html;
    if ($user) {
      my $url = $self->tx->req->url;
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
      $html = <<'ANON';
<form class="well" method="post" action="/login">
  <input type="text" class="input-small" placeholder="Username" name="username">
  <input type="password" class="input-small" placeholder="Password" name="password">
  <input type="submit" class="btn" value="Sign In">
</form>
ANON
    }
    return Mojo::ByteStream->new( $html );
  });

  $app->helper( 'set_menu' => sub {
    my $self = shift;

    my $name = (@_ == 0 or ref $_[0]) ? 'main' : shift();
    my $list = @_ ? shift() : $json->decode($schema->resultset('Menu')->single({name => $name})->list);
  
    my @pages = 
      map { my $page = $_; $page =~ s/^pages-//; $page}
      grep { ! /^header-/ }
      @$list;
  
    my $rs = $schema->resultset('Page');
    my $html;
    for my $id (@pages) {
      my $page = $rs->single({id => $id});
      $html .= sprintf '<li><a href="/pages/%s">%s</a></li>', $page->name, $page->title;
    }

    $schema->resultset('Menu')->update(
      {
        html => $html || '',
        list => $json->encode(\@pages),
      },
      { key => $name }
    );
  });

  $app->helper( 'get_menu' => sub {
    my $self = shift;
    my $name = shift || 'main';
    my $menu = $schema->resultset('Menu')->single({name => $name});
    return $menu->html;
  });

  my $r = $app->routes;

  $r->any( '/' => sub { shift->redirect_to('/pages/home') });

  $r->any( '/pages/:name' => sub {
    my $self = shift;
    my $name = $self->param('name');
    my $page = $schema->resultset('Page')->single({ name => $name });
    if ($page) {
      my $title = $page->title;
      $self->title( $title );
      $self->content_for( banner => $title );
      $self->render( pages => page_contents => $page->html );
    } else {
      if ($self->session->{username}) {
        $self->redirect_to("/edit/$name");
      } else {
        $self->render_not_found;
      }
    }
  });

  $r->post( '/login' => sub {
    my $self = shift;
    my $name = $self->param('username');
    my $pass = $self->param('password');

    my $user = $schema->resultset('User')->single({name => $name});
    if ($user and $user->check_password($pass)) {
      #TODO make this log the id for performance reasons
      $self->session->{username} = $name;
    }
    $self->redirect_to('/');
  });

  $r->any( '/logout' => sub {
    my $self = shift;
    $self->session( expires => 1 );
    $self->redirect_to('/');
  });

  $r->under( sub {
    my $self = shift;
    my $fail = sub {
      $self->redirect_to('/');
      return 0;
    };

    return $fail->() unless my $name = $self->session->{username};

    my $user = $schema->resultset('User')->single({name => $name});
    return $fail->() unless $user and $user->is_author;

    return 1;
  });

  $r->any( '/admin/menu' => sub {
    my $self = shift;
    my $name = 'main';
    my %active = 
      map { $_ => 1 } 
      @{ $json->decode(
        $schema->resultset('Menu')->single({name => $name})->list
      )};
  
    my ($active, $inactive);
    my @pages = $schema->resultset('Page')->all;
    for my $page ( @pages ) {
      next unless $page;
      my $name = $page->name;
      my $id   = $page->id;
      next if $name eq 'home';
      exists $active{$id} ? $active : $inactive 
        .= sprintf qq{<li id="pages-%s">%s</li>\n}, $id, $page->title;
    }

    $self->title( 'Setup Main Navigation Menu' );
    $self->content_for( banner => 'Setup Main Navigation Menu' );
    $self->render( menu => 
      active   => Mojo::ByteStream->new( $active   ), 
      inactive => Mojo::ByteStream->new( $inactive ),
    );
  });

  $r->any( '/edit/:name' => sub {
    my $self = shift;
    my $name = $self->param('name');
    $self->title( "Editing Page: $name" );
    $self->content_for( banner => "Editing Page: $name" );

    my $page = $schema->resultset('Page')->single({name => $name});
    if ($page) {
      my $title = $page->title;
      $self->stash( title_value => $title );
      $self->stash( input => $page->md );
    } else {
      $self->stash( title_value => '' );
      $self->stash( input => "Hello World" );
    }

    $self->render( 'edit' );
  });

  $r->websocket( '/store' => sub {
    my $self = shift;
    Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
    $self->on(message => sub {
      my ($self, $message) = @_;
      my $data = $json->decode($message);
      my $store = delete $data->{store};

      if ($store eq 'pages') {
        unless($data->{title}) {
          $self->send('Not saved! A title is required!');
          return;
        }
        my $author = $schema->resultset('User')->single({name=>$self->session->{username}});
        $data->{author_id} = $author->id;
        $schema->resultset('Page')->update_or_create(
          $data, {key => 'pages_name'},
        );
        $self->set_menu();
      } elsif ($store eq 'main_menu') {
        $self->set_menu($data->{list});
      }
      $self->send('Changes saved');
    });
  });
}

1;

