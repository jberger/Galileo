package Galileo::Command::database;
use Mojo::Base 'Mojolicious::Command';

use Term::Prompt qw/prompt/;

has description => "Create the database for your Galileo CMS application.\n";
has usage       => "usage: $0 setup\n";

use Galileo::DB::Deploy;

has 'dh' => sub {
  my $self = shift;
  Galileo::DB::Deploy->new( app => $self->app );
};

sub run {
  my ($self) = @_;

  $self->deploy_or_upgrade_schema;

  say "Run 'galileo daemon' to start the server.";
}

sub deploy_or_upgrade_schema {
  my $self = shift;
  my $dh = $self->dh;
  my $schema = $dh->schema;

  my $available = $schema->schema_version;

  # Nothing installed
  unless ( eval { $schema->resultset('User')->first } ) {
    say "Install database version: $available";
    $self->install_schema;
    return;
  }

  # Something is installed, check for a version
  my $installed = $dh->installed_version || $dh->setup_unversioned;

  # Do nothing if version is current
  if ( $installed == $available ) {
    say "Database schema is current";
    return;
  }

  say "Upgrade database $installed -> $available";

  $dh->upgrade;
}

sub install_schema {
  my $self = shift;
  my $dh = $self->dh;

  my ($user, $full, $pass) = $self->prompt_for_user_info;

  $dh->deploy;
  $dh->inject_sample_data($user, $pass, $full);
}

sub prompt_for_user_info {

  my $self = shift;

  my $user = prompt('x', 'Admin Username: ', '', '');
  my $full = prompt('x', 'Admin Full Name: ', '', '');
  my $pass1 = prompt('p', 'Admin Password: ', '', '');
  print "\n";

  #TODO check for acceptable password

  my $pass2 = prompt('p', 'Repeat Admin Password: ', '', '');
  print "\n";

  unless ($pass1 eq $pass2) {
    die "Passwords do not match";
  }

  return ( $user, $full, $pass1 );
}

1;
