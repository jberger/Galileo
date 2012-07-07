use Mojolicious::Lite;
use Mojo::ByteStream;
use Mojo::JSON;
my $json = Mojo::JSON->new();

use DBM::Deep;
my $db = DBM::Deep->new( 'myapp.db' );

#### some initial data ####
$db->{pages} ||= {
  me => { 
    html => '<p>Some really cool stuff about me</p>',
    md   => 'Some really cool stuff about me',
  },
};
  
$db->{users} ||= {
  joel => 'pass',
};

$db->{main_menu} ||= [ qw/ me / ];
###########################

get '/' => sub {
  my $self = shift;
  $self->render('hello');
};

get '/pages/:name' => sub {
  my $self = shift;
  my $name = $self->param('name');
  $self->title( "Page about $name" );
  if (exists $db->{pages}{$name}) {
    $self->stash( page_contents => $db->{pages}{$name}{html} );
    $self->render( 'pages' );
  } else {
    $self->render_not_found;
  }
};

helper login => sub {
  my $self = shift;
  my $user = $self->session->{username};
  my $html = $user ? <<USER : <<'ANON';
<div class="well" style="padding: 8px 0;">
  <ul class="nav nav-list">
    <li class="nav-header">Hello $user</li>
    <li><a href="/logout">Log Out</a></li>
  </ul>
</div>
USER
<form class="well" method="post" action="/login">
  <input type="text" class="input-small" placeholder="Username" name="username">
  <input type="password" class="input-small" placeholder="Password" name="password">
  <input type="submit" class="btn" value="Sign In">
</form>
ANON
  return Mojo::ByteStream->new( $html );
};

post '/login' => sub {
  my $self = shift;
  my $name = $self->param('username');
  my $pass = $self->param('password');
  if ($db->{users}{$name} eq $pass) {
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
  my $username = $self->session->{username};
  unless (defined $username and exists $db->{users}{$username}) {
    $self->redirect_to('/');
    return 0;
  }
  return 1;
};

get '/admin/menu' => sub {
  my $self = shift;
  my @active = @{ $db->{main_menu} };
  my @inactive = do {
    my %active = map { $_ => 1 } @active;
    sort grep { length and not exists $active{$_} } keys %{ $db->{pages} };
  };
  
  @active   = map { sprintf '<li id="pages-%s">%s</li>', $_, $_ } @active;
  @inactive = map { sprintf '<li id="pages-%s">%s</li>', $_, $_ } @inactive;
  
  my $active = '<ul id="list-active-pages" class="nav nav-list connectedSortable well">'
    . '<li id="header-active" class="nav-header">Active Pages</li>'
    . join( "\n", @active   ) . '</ul>' . "\n";
  my $inactive = '<ul id="list-inactive-pages" class="nav nav-list connectedSortable well">'
    . '<li id="header-inactive" class="nav-header">Inactive Pages</li>'
    . join( "\n", @inactive ) . '</ul>' . "\n";

  $self->render( menu => 
    active   => Mojo::ByteStream->new( $active   ), 
    inactive => Mojo::ByteStream->new( $inactive ),
  );
};

get '/edit/:name' => sub {
  my $self = shift;
  my $name = $self->param('name');
  $self->title( "Editing Page: $name" );

  if (exists $db->{pages}{$name}) {
    $self->stash( input => $db->{pages}{$name}{md} );
  } else {
    $self->stash( input => "Hello World" );
  }

  $self->render( 'edit' );
};

websocket '/store' => sub {
  my $self = shift;
  $self->on(message => sub {
    my ($self, $message) = @_;
    my $data = $json->decode($message);
    $db->{pages}{$data->{name}} = $data;
    $self->send('Changes saved');
  });
};

app->secret( 'MySecret' );
app->start;

__DATA__

@@ menu.html.ep
% layout 'standard';
% content_for header => begin
%= javascript '/assets/jquery-ui-1.8.21.custom.min.js'
% end

%= javascript begin
	$(function() {
		$( "#list-active-pages, #list-inactive-pages" ).sortable({
			connectWith: ".connectedSortable",
      cancel: ".nav-header"
		}).disableSelection();
	});
%= end

<div class="row">
  <div class="span5">
    <%= $active %> 
  </div>
  <div class="span5">
    <%= $inactive %>
  </div>
</div>

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
  name : "<%= $name  %>",
  md : "",
  html : "",
};

ws = new WebSocket("<%= url_for('store')->to_abs %>");
ws.onmessage = function (evt) {
  var message = evt.data;
  console.log( message );
  humane.log( message );
};

function saveButton() {
  var serialized = JSON.stringify(data);
  console.log( "Sending ==> " + serialized );
  ws.send( serialized );
}

%= end

<div class="wmd-panel">
  <div id="wmd-button-bar"></div>
  <textarea class="wmd-input" id="wmd-input"><%= $input %></textarea>
  <div id="wmd-preview" class="wmd-preview well"></div>
  <div id="alert-area"></div>
  <button class="btn" id="save-md" onclick="saveButton()">
    Save
  </button>
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

@@ hello.html.ep
% title 'Hello World';
% layout 'standard';
% content_for banner => begin
Hello World
% end
This is the site

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
          <li><a href="/pages/me">About Me</a></li>
        </ul>
      </div>
      %= login
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

