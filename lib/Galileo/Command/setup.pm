package Galileo::Command::setup;
use Mojo::Base 'Mojolicious::Command';

use Mojolicious::Command::daemon;

use Mojolicious::Routes;
use Mojo::JSON 'j';
use Mojo::Util 'spurt';

use Galileo::DB::Deploy;

has description => "Configure your Galileo CMS via a web interface\n";

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

    # map JSON keys to Perl data
    my %params = map { $_ => scalar $self->param($_) } @params;
    foreach my $key ( qw/extra_css extra_js extra_static_paths secrets db_options/ ) {
      $params{$key} = j($params{$key});
    }

    spurt $self->dumper(\%params), $self->app->config_file;
  
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
    unless ( $dh->has_admin_user ) {
      return $self->render( 'galileo_database_install' );
    }

    # Something is installed, check for a version
    my $installed = $dh->installed_version || $dh->setup_unversioned;

    # Do nothing if version is current
    if ( $installed == $available ) {
      $self->flash( 'galileo.message' => 'Database schema is current' );
    } else {
      $self->flash( 'galileo.message' => "Upgrade database $installed -> $available" );
      $dh->do_upgrade;
    }

    $self->redirect_to('finish');
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

    eval { $dh->schema->deploy };
    eval { $dh->do_install };
    eval { $dh->inject_sample_data($user, $pw1, $full) };
    if ($@) {
      my $error = "$@";
      chomp $error;
      $self->humane_flash( $error );
      return $self->redirect_to('database');
    }

    $self->flash( 'galileo.message' => 'Database has been setup' );
    $self->redirect_to('finish');
  });

  $r->any('/finish' => sub {
    my $self = shift;
    my $message = $self->flash( 'galileo.message' );

    # check that an admin user exists
    if ( $self->app->dh->has_admin_user ) {
      $self->stash( 'galileo.success' => 1 );
      $self->stash( 'galileo.message' => $message );
    } else {
      $self->stash( 'galileo.success' => 0 );
      $self->stash( 
        'galileo.message' =>
        'It does not appear that your database is setup, please rerun the setup utility'
      );
    }

    $self->humane_stash( 'Goodbye' );
    $self->render('galileo_finish');
    $self->tx->on( finish => sub { exit } );
  });

  $self->Mojolicious::Command::daemon::run(@args);
}

1;


__DATA__

@@ galileo_setup.html.ep

% title 'Galileo Setup - Home';
% layout 'basic';

<p>Welcome to Galileo! This utility helps you setup your Galileo CMS.</p>

<ul>
  %= tag li => begin 
    %= link_to 'Configure your Galileo CMS' => 'configure'
    <p>Configuration is not necessary, defaults can be used. 
    Configuring Galileo CMS should be done before installing the database.</p>
  % end

  %= tag li => begin
    %= link_to 'Install or upgrade your database' => 'database'
    <p>If this is a new installation you <b>must</b> to run the database setup utility.
    If you have not configured Galileo (see above), you will use the defaults, including using an SQLite database for the backend.</p>
  % end

  %= tag li => begin
    %= link_to 'Stop and exit' => 'finish'
    <p>If your database is already installed, you may stop this utility and run <pre>$ galileo daemon</pre></p>
  % end

</ul>

@@ galileo_config.html.ep

% use Mojo::JSON 'j';
% title 'Galileo Setup - Configure';
% layout 'basic';

%= form_for 'store_config' => method => 'POST', class => 'form-horizontal' => begin
  % my $config = app->config;

  <legend>Database Connection</legend>
  %= control_group for => 'db_dsn', label => 'Connection String (DSN)' => begin
    %= text_field 'db_dsn', value => $config->{db_dsn}, class => 'input-block-level'
  % end
  %= control_group for => 'db_username', label => 'Username' => begin
    %= text_field 'db_username', value => $config->{db_username}, class => 'input-block-level'
  % end
  %= control_group for => 'db_password', label => 'Password' => begin
    %= input_tag 'db_password', value => $config->{db_password}, type => 'password', class => 'input-block-level'
  % end
  %= control_group for => 'db_options', label => 'Options (JSON hash)' => begin
    %= text_field 'db_options', value => j($config->{db_options}), class => 'input-block-level'
  % end
  %= control_group for => 'db_schema', label => 'Schema Class' => begin
    %= text_field 'db_schema', value => $config->{db_schema}, class => 'input-block-level'
  % end

  <legend>Additional Files</legend>

  %= control_group for => 'files', label => 'Extra Static Paths (JSON array)' => begin
    %= text_field 'extra_static_paths', value => j($config->{extra_static_paths}), class => 'input-block-level'
  % end
  %= control_group for => 'extra_js', label => 'Extra Javascript Files (JSON array)' => begin
    %= text_field 'extra_js', value => j($config->{extra_js}), class => 'input-block-level'
  % end
  %= control_group for => 'extra_css', label => 'Extra Stylesheet files (JSON array)' => begin
    %= text_field 'extra_css', value => j($config->{extra_css}), class => 'input-block-level'
  % end
  %= control_group for => 'upload_path', label => 'Upload Path' => begin
    %= text_field 'upload_path', value => $config->{upload_path}, class => 'input-block-level'
  % end

  <legend>Other Options</legend>

  %= control_group for => 'sanitize', label => 'Use Sanitizing Editor' => begin 
    % if($config->{sanitize}){
      %= check_box 'sanitize', value => 1, checked => 'checked'
    % } else {
      %= check_box 'sanitize', value => 1
    % }
    %= hidden_field 'sanitize' => 0
  % end
  %= control_group for => 'secrets', label => 'Application Secrets (JSON array)' => begin
    %= text_field 'secrets', value => j($config->{secrets}), class => 'input-block-level'
  % end
  %= control_group for => 'submit-button', begin
    <button class="btn" id="submit-button" type="submit">Save</button>
    %= link_to 'Cancel' => '/' => class => 'btn'
  % end
% end

@@ galileo_database_install.html.ep

% title 'Galileo Setup - Database';
% layout 'basic';

%= form_for 'database_install' => method => 'POST', class => 'form-horizontal' => begin
  %= control_group for => 'full', label => 'Admin Full Name' => begin
    %= text_field 'full', class => 'input-block-level'
  % end
  %= control_group for => 'user', label => 'Admin Username' => begin
    %= text_field 'user', class => 'input-block-level'
  % end
  %= control_group for => 'pw1', label => 'Password' => begin
    %= input_tag 'pw1', type => 'password', class => 'input-block-level'
  % end
  %= control_group for => 'pw2', label => 'Repeat Password' => begin
    %= input_tag 'pw2', type => 'password', class => 'input-block-level'
  % end

  %= control_group for => 'submit-button', begin
    <button class="btn" id="submit-button" type="submit">Save</button>
    %= link_to 'Cancel' => 'finish' => class => 'btn'
  % end
% end

@@ galileo_finish.html.ep

% title 'Galileo Setup - Finished';
% layout 'basic';

% if ( my $message = stash 'galileo.message' ) {
  <p><%= $message %></p>
% }

% if ( stash 'galileo.success' ) {
  <p>Setup complete, run <pre>$ galileo daemon</pre></p>
% }

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
