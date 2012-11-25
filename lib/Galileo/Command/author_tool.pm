package Galileo::Command::author_tool;
use Mojo::Base 'Mojolicious::Command';

use DBIx::Class::DeploymentHandler;

sub run {
  my ($self) = @_;

  shift @ARGV;
  my $command = shift @ARGV;
  my $method = $self->can($command) or die "No command: $command\n";

  $self->$method();
}

sub generate_install_scripts {
  my $self = shift;

  my $schema = $self->app->schema;
  my $dh = DBIx::Class::DeploymentHandler->new({
    schema => $schema,
    databases => [],
    script_directory => 'lib/Galileo/files/sql',
  });
  my $version = $schema->schema_version;

  say "generating deployment script";
  $dh->prepare_install;

}

1;

