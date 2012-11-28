use strict;
use warnings;

use File::Temp;

use Galileo::DB::Schema;
use Galileo::DB::Deploy;

my $dir = File::Temp->newdir;

my $schema = Galileo::DB::Schema->connect('dbi:SQLite:dbname=:memory:');
my $dh = Galileo::DB::Deploy->new( schema => $schema, script_directory => "$dir", ignore_ddl => 1, databases => [] );

$dh->prepare_deploy;
$dh->deploy();
print $dh->installed_version . "\n";
