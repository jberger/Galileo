package Galileo::Command::setup;
use Mojo::Base 'Mojolicious::Command';

use Term::Prompt qw/prompt/;

has description => "Deploy/upgrade the database for your Galileo CMS application.\n";
has usage       => "usage: $0 setup\n";

use Galileo::DB::Deploy;

sub run {
  my ($self) = @_;

  print <<'END';

#############
#  Welcome  #
#############

This is Galileo's database installation and upgrade tool.

By default it will install a new SQLite database called 'galileo.db' in your current
working directory. You may change these behaviors using the following 
environment variables:

  GALILEO_HOME 

    The full path to a directory which will contain any configuration
    files, the SQLite database (if applicable) and any static content.
    The default is the current working directory.

  GALILEO_CONFIG

    The name of the configuration file controlling the rest of Galileo's
    functionality. The default is 'galileo.conf'.

The remaining behaviors, including the database connection can be controlled by using 
this configuration file. To create this file, please abort this script and run 
`galileo config` first, then edit the file it creates.

############
#  Secret  #
############

Finally, while you do not NEED a configuration file, one more thing that it does is set
the "Secret" for you website. This helps to keep you site secure, you really should
set it. Mojolicious will warn you until you do.

END

print '  FYI, your secret is ...... ' . ( $self->app->config->{secret} ? 'SET' : 'NOT SET' ) . "\n";

print <<'END';

#################
#  Please Note  #
#################

Unfortunately the database migration tools sometimes spit out warnings like

  Overwriting existing DDL-YML file - /tmp/JG6_FothpG ... 

or 

  SV = IV(0x5042fd8) at 0x5042fe8 ...

These messages do not come from Galileo. They can safely be ignored and bugs have 
been filed where necessary. Thanks for your understanding.

########################
#  Let's get started!  #
########################

END

  my $dh = Galileo::DB::Deploy->new( schema => $self->app->schema );
  $self->deploy_or_upgrade_schema( $dh );

  print <<'END';

##############
#  Complete  #
##############

All necessary actions have finished.
Please run 'galileo daemon' to start the server.


END
}

sub deploy_or_upgrade_schema {
  my $self = shift;
  my $dh = shift;
  my $schema = $dh->schema;

  my $available = $schema->schema_version;

  # Nothing installed
  unless ( eval { $schema->resultset('User')->first } ) {
    say "Installing database version: $available";
    $self->install_schema( $dh );
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

  $dh->do_upgrade;
}

sub install_schema {
  my $self = shift;
  my $dh = shift;

  my ($user, $full, $pass) = $self->prompt_for_user_info;

  $dh->do_install;
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
