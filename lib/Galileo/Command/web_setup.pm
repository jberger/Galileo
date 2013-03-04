package Galileo::Command::web_setup;
use Mojo::Base 'Mojolicious::Command';

use Mojolicious::Command::daemon;

use Mojolicious::Routes;
use Mojo::JSON 'j';
use Data::Dumper;

use Galileo::DB::Deploy;

has description => "Configure your application via a web interface\n";

sub run {
  my ($self, @args) = @_;

  my $app = $self->app;

  my $r = Mojolicious::Routes->new;
  $app->routes($r); # remove all routes

  push @{ $app->renderer->classes }, __PACKAGE__;

  $app->helper( dh => sub {
    my $self = shift;
    state $dh = Galileo::DB::Deploy->new( schema => $self->app->schema );
    $dh;
  });

  $app->helper( 'control_group' => sub {
    my $self = shift;
    my $contents = pop;
    my %args = @_;
 
    $self->render(
      partial => 1,
      template => 'control_group',
      'control_group.contents' => ref $contents ? $contents->() : $contents,
      'control_group.label' => $args{label} || '',
      'control_group.for'   => $args{for}   || '',
    );
  });

  $r->any( '/' => 'galileo_setup' );
  $r->any( '/configure' => 'galileo_config' );
  $r->any( '/store_config' => sub {
    my $self = shift;
    my @params = sort $self->param;

    {
      my @config = sort keys %{ $self->app->config };

      # check that all keys are represented
      die "Incorrect number of configuration keys"
        unless @params == @config;

      for my $i (0 .. $#params) {
        die "Config key mismatch $config[$i] vs $params[$i]"
          unless $config[$i] eq $params[$i];
      }
    }

    # map JSON keys to Perl data
    my %params = map { $_ => scalar $self->param($_) } @params;
    foreach my $key ( qw/files extra_css extra_js db_options/ ) {
      $params{$key} = j($params{$key});
    }

    {
      my $file = $self->app->config_file;
      open my $fh, '>', $file
        or die "Could not open file $file for writing: $!\n";

      local $Data::Dumper::Terse = 1;
      local $Data::Dumper::Sortkeys = 1;

      print $fh Dumper \%params 
        or die "Write to $file failed\n";
    }
  
    $self->app->load_config;
    $self->humane_flash( 'Configuration saved' );
    $self->redirect_to('/');
  });

  $r->any( '/database' => sub {
    my $self = shift;

    my $dh = $self->dh;
    my $schema = $dh->schema;

    my $available = $schema->schema_version;

    # Nothing installed
    unless ( eval { $schema->resultset('User')->first } ) {
      return $self->render( 'galileo_database_install' );
    }

    # Something is installed, check for a version
    my $installed = $dh->installed_version || $dh->setup_unversioned;

    # Do nothing if version is current
    if ( $installed == $available ) {
      $self->humane_flash( 'Database schema is current' );
    } else {
      $self->humane_flash( "Upgrade database $installed -> $available" );
      $dh->do_upgrade;
    }

    $self->redirect_to('finished');
  });

  $r->any( '/database_install' => sub {
    my $self = shift;
    my $pw1 = $self->param('pw1');
    my $pw2 = $self->param('pw2');
    unless ( $pw1 eq $pw2 ) {
      $self->humane_flash( q{Passwords don't match!} );
      return $self->redirect_to('database');
    }

    my $dh = $self->dh;
    my $user = $self->param('user');
    my $full = $self->param('full');

    $dh->do_install;
    $dh->inject_sample_data($user, $pw1, $full);

    $self->humane_flash('Database setup');
    $self->redirect_to('finish');
  });

  $r->any('/finish' => 'galileo_finish');

  $r->any('/exit' => sub { exit });

  $self->Mojolicious::Command::daemon::run(@args);
}

1;


__DATA__

@@ layouts/galileo_layout.html.ep

<!DOCTYPE html>
<html>
  <head>
    %= include 'header_common';
  </head>
  <body>
    <div class="container">
      <h1><%= title %></h1>
      %= content
    </div>
  </body>
</head>

@@ galileo_setup.html.ep

% title 'Galileo Setup - Home';
% layout 'galileo_layout';

<p>Welcome to Galileo! This utility helps you setup your Galileo CMS.</p>

<ul>
  %= tag li => begin 
    You may want to set some configuration parameters. If you do not first visit the configuration page, you will use the defaults, including using an SQLite database for the backend.
    <ul><li>
      %= link_to 'Configure your Galileo CMS' => 'configure'
    </li></ul>
  % end

  %= tag li => begin
    If this is a new installation you <b>must</b> to run the database setup utility.
    <ul><li>
      %= link_to 'Install or upgrade your database' => 'database'
    </li></ul>
  % end

  %= tag li => begin
    When you are ready stop this utility and run <pre>$ galileo daemon</pre>
    <ul><li>
      %= link_to 'Stop and exit' => 'finish'
    </li></ul>
  % end

</ul>

@@ galileo_config.html.ep

% use Mojo::JSON 'j';
% title 'Galileo Setup - Configure';
% layout 'galileo_layout';

%= form_for 'store_config' => method => 'POST', class => 'form-horizontal' => begin
  % my $config = app->config;

  <legend>Database Connection</legend>
  %= control_group for => 'db_dsn', label => 'Connection String (DSN)' => begin
    %= text_field 'db_dsn', value => $config->{db_dsn}
  % end
  %= control_group for => 'db_username', label => 'Username' => begin
    %= text_field 'db_username', value => $config->{db_username}
  % end
  %= control_group for => 'db_password', label => 'Password' => begin
    %= input_tag 'db_password', value => $config->{db_password}, type => 'password'
  % end
  %= control_group for => 'db_options', label => 'Options (JSON hash)' => begin
    %= text_field 'db_options', value => j($config->{db_options})
  % end
  %= control_group for => 'db_schema', label => 'Schema Class' => begin
    %= text_field 'db_schema', value => $config->{db_schema}
  % end

  <legend>Additional Files</legend>

  %= control_group for => 'files', label => 'Static Files (JSON array)' => begin
    %= text_field 'files', value => j($config->{files})
  % end
  %= control_group for => 'extra_js', label => 'Extra Javascript Files (JSON array)' => begin
    %= text_field 'extra_js', value => j($config->{extra_js})
  % end
  %= control_group for => 'extra_css', label => 'Extra Stylesheet files (JSON array)' => begin
    %= text_field 'extra_css', value => j($config->{extra_css})
  % end

  <legend>Other Options</legend>

  %= control_group for => 'sanitize', label => 'Use Sanitizing Editor' => begin 
    %= check_box 'sanitize', value => 1, checked => $config->{sanitize} ? 'checked' : ''
  % end
  %= control_group for => 'secret', label => 'Application Secret' => begin
    %= text_field 'secret', value => $config->{secret}
  % end
  %= control_group for => 'submit-button', begin
    <button class="btn" id="submit-button" type="submit">Save</button>
    %= link_to 'Cancel' => '/' => class => 'btn'
  % end
% end

@@ galileo_database_install.html.ep

% title 'Galileo Setup - Database';
% layout 'galileo_layout';

%= form_for 'database_install' => method => 'POST', class => 'form-horizontal' => begin
  %= control_group for => 'full', label => 'Admin Full Name' => begin
    %= text_field 'full'
  % end
  %= control_group for => 'user', label => 'Admin Username' => begin
    %= text_field 'user'
  % end
  %= control_group for => 'pw1', label => 'Password' => begin
    %= input_tag 'pw1', type => 'password'
  % end
  %= control_group for => 'pw2', label => 'Password' => begin
    %= input_tag 'pw2', type => 'password'
  % end

  %= control_group for => 'submit-button', begin
    <button class="btn" id="submit-button" type="submit">Save</button>
    %= link_to 'Cancel' => 'finish' => class => 'btn'
  % end
% end

@@ galileo_finish.html.ep

% title 'Galileo Setup - Finished';
% layout 'galileo_layout';

<p>
  Setup complete, run <pre>$ galileo daemon</pre>
</p>

%= javascript begin
  $(function(){ $.get('<%= url_for 'exit' %>') });
% end

@@ control_group.html.ep

<div class="control-group">
  % if (my $label = stash 'control_group.label') {
    % my @for;
    % if ( my $for = stash 'control_group.for' ) {
      % push @for, for => $for;
    % }
    %= tag label => class => 'control-label', @for, begin
      %= $label 
    % end
  % }
 
  <div class="controls">
    %= stash 'control_group.contents'
  </div>
</div>
