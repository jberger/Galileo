package Galileo::Command::config;
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

  my $file = $self->app->config_file;

  if (-e $file and not $force) {
    die "Configuration file $file exists, use '--force' option to proceed anyway.\n";
  }

  my $config = $self->app->config;
  local $config->{secret} = prompt('x', 'Application Secret: ', '', '');

  open my $fh, '>', $file 
    or die "Could not open file $file for writing: $!\n";

  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Sortkeys = 1;

  print $fh Dumper $config 
    or die "Write to $file failed\n";

  print "Configuration file $file written sucessfully\n";
}

1;

