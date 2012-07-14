use Mojolicious::Lite;
use Mojo::ByteStream;

plugin Config => { default => {
  db_schema  => 'MojoCMS::DB::Schema',
  db_connect => 'dbi:SQLite:dbname=mojocms_sqlite.db',
  secret     => 'MySecret',
}};

app->secret( app->config->{secret} );

use Mojo::JSON;
my $json = Mojo::JSON->new();

use lib 'lib';

helper 'db_connect' => sub {
  my $self = shift;
  my $schema_class = $self->app->config->{db_schema} or die "Unknown DB Schema Class";
  eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

  my $db_connect = $self->app->config->{db_connect} or die "No DBI connection string provided";
  my $schema = $schema_class->connect( $db_connect ) 
    or die "Could not connect to $schema_class using $db_connect";

  return $schema;
};

my $schema = app->db_connect;

get '/' => sub {
  my $self = shift;
  $self->redirect_to('/pages/home');
};

get '/pages/:name' => sub {
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
};

helper user_menu => sub {
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
};

helper 'set_menu' => sub {
  my $self = shift;
  my $name = ref $_[0] ? 'main' : shift();
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
};

helper 'get_menu' => sub {
  my $self = shift;
  my $name = shift || 'main';
  my $menu = $schema->resultset('Menu')->single({name => $name});
  return $menu->html;
};

post '/login' => sub {
  my $self = shift;
  my $name = $self->param('username');
  my $pass = $self->param('password');

  my $user = $schema->resultset('User')->single({name => $name});
  if ($user and $user->pass eq $pass) {
    #TODO make this log the id for performance reasons
    $self->session->{username} = $name;
  }
  $self->redirect_to('/');
};

any '/logout' => sub {
  my $self = shift;
  $self->session( expires => 1 );
  $self->redirect_to('/');
};

under sub {
  my $self = shift;
  my $fail = sub {
    $self->redirect_to('/');
    return 0;
  };

  return $fail->() unless my $name = $self->session->{username};

  my $user = $schema->resultset('User')->single({name => $name});
  return $fail->() unless $user and $user->is_author;

  return 1;
};

get '/admin/menu' => sub {
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
};

get '/edit/:name' => sub {
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
};

websocket '/store' => sub {
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
        $data, {key => 'page_name'},
      );
      $self->set_menu();
    } elsif ($store eq 'main_menu') {
       $self->set_menu($data->{list});
    }
    $self->send('Changes saved');
  });
};

app->start;

__DATA__

@@ menu.html.ep
% layout 'standard';
% content_for header => begin
%= javascript '/assets/jquery-ui-1.8.21.custom.min.js'
% end

%= javascript begin
ws = new WebSocket("<%= url_for('store')->to_abs %>");
ws.onmessage = function (evt) {
  var message = evt.data;
  console.log( message );
  humane.log( message );
};
function saveButton() {
  var data = {
    store : "main_menu",
    list : $("#list-active-pages").sortable('toArray')
  };
  var serialized = JSON.stringify(data);
  console.log( "Sending ==> " + serialized );
  ws.send( serialized );
}

	$(function() {
		$( "#list-active-pages, #list-inactive-pages" ).sortable({
			connectWith: ".connectedSortable",
      items: "li:not(.nav-header)"
		}).disableSelection();
	});
%= end

<div class="row">
  <div class="span5">
    <ul id="list-active-pages" class="nav nav-list connectedSortable well">
      <li id="header-active" class="nav-header">Active Pages</li>
      <%= $active %>
    </ul>
  </div>
  <div class="span5">
    <ul id="list-inactive-pages" class="nav nav-list connectedSortable well">
      <li id="header-inactive" class="nav-header">Inactive Pages</li>
      <%= $inactive %>
    </ul>
  </div>
</div>
<button class="btn" id="save-list" onclick="saveButton()">
  Save
</button>

@@ edit.html.ep
% layout 'standard';
% content_for header => begin
%= stylesheet '/assets/pagedown/demo.css'
%= javascript '/assets/pagedown/Markdown.Converter.js'
%= javascript '/assets/pagedown/Markdown.Sanitizer.js'
%= javascript '/assets/pagedown/Markdown.Editor.js'
% end

%= javascript begin
data = {
  store : "pages",
  name  : "<%= $name  %>",
  md    : "",
  html  : "",
  title : ""
};

ws = new WebSocket("<%= url_for('store')->to_abs %>");
ws.onmessage = function (evt) {
  var message = evt.data;
  console.log( message );
  humane.log( message );
};

function saveButton() {
  data.title = $("#page-title").val();
  var serialized = JSON.stringify(data);
  console.log( "Sending ==> " + serialized );
  ws.send( serialized );
}

%= end

<div class="wmd-panel">
  <div class="well form-inline">
    <input 
      type="text" 
      id="page-title" 
      placeholder="Page Title" 
      value="<%= $title_value %>"
    >
    <button class="btn" id="save-md" onclick="saveButton()">
      Save Page
    </button>
  </div>
  <div id="wmd-button-bar"></div>
  <textarea class="wmd-input" id="wmd-input"><%= $input %></textarea>
  <div id="wmd-preview" class="wmd-preview well"></div>
  <div id="alert-area"></div>
</div>

%= javascript begin
(function () {
  var converter = Markdown.getSanitizingConverter();
  var editor = new Markdown.Editor(converter);
  converter.hooks.chain("preConversion", function (text) {
    data.md = text;
    return text; 
  });
  converter.hooks.chain("postConversion", function (text) {
    data.html = text;
    return text; 
  });
  editor.run();
})();
%= end

@@ pages.html.ep
% layout 'standard';
%== $page_contents

@@ layouts/standard.html.ep
<!DOCTYPE html>
<html>
<head>
  %= include 'header_common'
  <%= content_for 'header' %>
</head>
<body>
<div class="container">
  <div class="page-header">
    <h1><%= content_for 'banner' %></h1>
  </div>
  <div class="row">
    <div class="span2">
      <div class="well" style="padding: 8px 0;">
        <ul class="nav nav-list">
          <li class="nav-header">Navigation</li>
          <li><a href="/">Home</a></li>
          <%== get_menu %>
        </ul>
      </div>
      <%= user_menu %>
    </div>
    <div class="span10">
      <%= content %>
    </div>
  </div>
</div>
</body>
</html>

@@ header_common.html.ep
<title><%= title %></title>
%= javascript '/assets/jquery-1.7.2.min.js'
%= javascript '/assets/bootstrap/js/bootstrap.js'
%= stylesheet '/assets/bootstrap/css/bootstrap.css'
%= javascript '/assets/humane/humane.min.js'
%= stylesheet '/assets/humane/libnotify.css'
%= javascript begin
  humane.baseCls = 'humane-libnotify'
%= end

