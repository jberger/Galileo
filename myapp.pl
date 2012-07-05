use Mojolicious::Lite;
use Mojo::JSON;
my $json = Mojo::JSON->new();

my %pages = (
  me => { 
    html => '<p>Some really cool stuff about me</p>',
    md   => 'Some really cool stuff about me',
  },
);

my %users = (
  joel => 'pass',
);

get '/' => sub {
  my $self = shift;
  $self->render('hello');
};

get '/pages/:name' => sub {
  my $self = shift;
  my $name = $self->param('name');
  $self->title( "Page about $name" );
  if (exists $pages{$name}) {
    $self->stash( page_contents => $pages{$name}{html} );
    $self->render( 'pages' );
  } else {
    $self->render_not_found;
  }
};

get '/login' => sub {
  my $self = shift;
  $self->session( expires => 1 );
  $self->render( 'login' );
};

post '/check' => sub {
  my $self = shift;
  my $name = $self->param('username');
  my $pass = $self->param('password');
  if ($users{$name} eq $pass) {
    $self->session->{username} = $name;
  }
  $self->redirect_to('/');
};

under sub {
  my $self = shift;
  my $username = $self->session->{username};
  return 1 if exists $users{$username};
  $self->redirect_to('/');
};

get '/edit/:name' => sub {
  my $self = shift;
  my $name = $self->param('name');
  $self->title( "Editing Page: $name" );

  if (exists $pages{$name}) {
    $self->stash( input => $pages{$name}{md} );
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
    $pages{$data->{name}} = $data;
    $self->send('Changes saved');
  });
};

app->secret( 'MySecret' );
app->start;

__DATA__

@@ login.html.ep
% layout 'standard';
%= form_for check => (method => 'POST') => begin
  %= text_field 'username'
  %= text_field 'password'
  %= submit_button
% end


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

function newAlert (type, message) {
    $("#alert-area").append($("<div class='alert alert-" + type + " fade in'>" + message + "</div>"));
    $("#alert-area").delay(2000).fadeOut("slow", function () { $(this).remove(); });
}

ws = new WebSocket("<%= url_for('store')->to_abs %>");
ws.onmessage = function (evt) {
  var message = evt.data;
  console.log( message );
  newAlert('success', message );
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
          <li><a href="/login">Log In</a></li>
        </ul>
      </div>
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

