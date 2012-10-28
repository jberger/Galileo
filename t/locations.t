use strict;
use warnings;

use Cwd;
use File::Temp;
my $home = File::Temp->newdir;
$ENV{GALILEO_HOME} = "$home";

use Galileo;
use Galileo::DB::Schema;
use Galileo::Command::setup;

use Test::More;
END{ done_testing(); }

use Test::Mojo;

# create a test file at $home/static/test.html

my $orig = getcwd;

chdir "$home" or die "Could not chdir to $home";

mkdir 'static' or die "Could not create 'static' directory in $home";
chdir 'static' or die "Could not chdir to 'static' directory in $home";
my $static = getcwd;

{
  open my $fh, '>', 'test.html';
  print $fh <<'END';
<!DOCTYPE html>
<html>
  <head></head>
  <body>test text</body>
</html>
END
}

chdir $orig or die "Could not chdir back to $orig";

my $db = Galileo::DB::Schema->connect('dbi:SQLite:dbname=:memory:');
Galileo::Command::setup->inject_sample_data('admin', 'pass', 'Joe Admin', $db);
ok( $db->resultset('User')->single({name => 'admin'})->check_password('pass'), 'DB user checks out' );

my $t = Test::Mojo->new(Galileo->new(db => $db));
my $app = $t->app;

is( $app->home, $home, 'home dir detected from GALILEO_HOME' );
ok( grep { $_ eq $static } @{ $app->static->paths }, "'static' directory is encluded in static paths" );

$t->get_ok('/test.html')
  ->status_is(200)
  ->text_is('body' => 'test text');
