package Galileo::Command::config;
use feature qw/switch/;
use Mojo::Base 'Mojolicious::Command';

use Data::Dumper;
use Term::Prompt qw/prompt/;
use Getopt::Long;

has description => "Write an optional configuration file for your Galileo CMS application.\n";
has usage       => "usage: $0 config\n";

sub run {

  my $self = shift;
  local @ARGV = @_;

  my $force = 0;
  GetOptions( "force" => \$force );

	my @db_types = qw ( SQLite Pg mysql );	

  my $file = $self->app->config_file;

  if (-e $file and not $force) {
    die "Configuration file $file exists, use '--force' option to proceed anyway.\n";
  }

  my $config = $self->app->config;
  local $config->{secret} 	= prompt('x', 'Application Secret: ', '', '');
  local $config->{sanitize} = prompt('y', 'Use Sanitizing Editor: ', '', 'Yes');
  local $config->{db_type}	= @db_types[(prompt("m", {
                         prompt           => "Database",
                         title            => 'Choose Database Type',
                         items            => \@db_types,
                         order            => 'across',
                         rows             => 1,
                         cols             => 10,
                         display_base     => 1,
                         return_base      => 1,
                         accept_multiple_selections => 0,
                         accept_empty_selection     => 1,
                        },
                   "", "SQLite") || 1) - 1]; 


	my($host, $port, $db_name, $user, $pass1, $pass2);

	$db_name = prompt('x', 'Database Name','','galileo');
	$db_name ||= 'galileo';

	if($config->{db_type} ne 'SQLite'){

		$user		= prompt('x', "$db_name User",'','galileo');
		$user ||= 'galileo';

		$pass1 	= prompt('p', "$db_name Password: ", '', '');
  	print "\n";
		$pass2 	= prompt('p', "Repeat $db_name Password: ", '', '');
	  print "\n";

	  unless ($pass1 eq $pass2) {
	    die "Passwords do not match";
	  }
	}

	given ($config->{db_type}) {
		
		when ('Pg') {
			my $host = '127.0.0.1';
			my $port = 5432;
			$host 			= prompt('x', 'Host: ', '', $host);
			$port 			= prompt('x', 'Port: ', '', $port);
			$config->{db_connect}[0] = "dbi:Pg:host=$host port=$port dbname=$db_name",
			$config->{db_connect}[1] = $user,
			$config->{db_connect}[2] = $pass1,
			$config->{db_connect}[3] = {
        'AutoCommit' => 1,
        'PrintError' => 1,
        'RaiseError' => 1,
        'on_connect_do' => 'SET search_path TO public,galileo',
        'pg_enable_utf8' => 1
      },
		}

		when ('mysql'){
			my $host = '127.0.0.1';
			my $port = 3306;
			$host 			= prompt('x', 'Host: ', '', $host);
			$port 			= prompt('x', 'Port: ', '', $port);
			$config->{db_connect}[0] = "DBI:mysql:database=$db_name;host=$host;port=$port",
			$config->{db_connect}[1] = $user,
			$config->{db_connect}[2] = $pass1,
			$config->{db_connect}[3] = {
        'AutoCommit' => 1,
        'PrintError' => 1,
        'RaiseError' => 1,
        'on_connect_do' => "SET NAMES utf8;",
        'mysql_enable_utf8' => 1,
				'set_strict_mode' => 1,
      },
	
		}

		default {
			$config->{db_connect}[0] = 'dbi:SQLite:dbname=' . $self->app->home->rel_file( "${db_name}.db" ),
			$config->{db_connect}[1] =    undef,
			$config->{db_connect}[2] =    undef,
			$config->{db_connect}[3] =    { sqlite_unicode => 1 },
		}

	}

  open my $fh, '>', $file 
    or die "Could not open file $file for writing: $!\n";

  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Sortkeys = 1;

  print $fh Dumper $config 
    or die "Write to $file failed\n";

  print "Configuration file $file written sucessfully\n";
}

1;

