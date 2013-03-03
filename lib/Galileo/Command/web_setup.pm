package Galileo::Command::web_setup;
use Mojo::Base 'Mojolicious::Command';

use Mojolicious::Command::daemon;

use Mojolicious::Routes;
use Mojo::JSON 'j';
use Data::Dumper;

has description => "Configure your application via a web interface\n";

sub run {
  my ($self, @args) = @_;

  my $app = $self->app;

  my $r = Mojolicious::Routes->new;
  $app->routes($r); # remove all routes

  push @{ $app->renderer->classes }, __PACKAGE__;

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

  $r->any( '/configuration' => 'galileo_config' );
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

    my $file = $self->app->config_file;
    open my $fh, '>', $file
      or die "Could not open file $file for writing: $!\n";

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;

    print $fh Dumper \%params 
      or die "Write to $file failed\n";

    $self->humane_flash( 'Configuration saved' );
    $self->redirect_to('/');
  });

  $self->Mojolicious::Command::daemon::run(@args);
}

1;


__DATA__

@@ galileo_config.html.ep

% use Mojo::JSON 'j';
% title 'Galileo Configuration';

<!DOCTYPE html>
<html>
<head>
  %= include 'header_common'
</head>
<body>
  <div class="container">
  <h1><%= title %></h1>

  %= form_for 'store' => method => 'POST', class => 'form-horizontal' => begin
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
    % end
  % end
  </div>
</body>
</html>

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
