use strict;
use warnings;

use MojoCMS::DB::Schema;

use Mojo::JSON;
my $json = Mojo::JSON->new();

my $schema = MojoCMS::DB::Schema->connect('dbi:SQLite:dbname=:memory:');
$schema->deploy;

my $admin = $schema->resultset('User')->create({
  name => 'admin',
  password => 'pass',
  is_author => 1,
  is_admin  => 1,
});

$schema->resultset('Page')->create({
  name      => 'home',
  title     => 'Home Page',
  html      => '<p>Welcome to the site!</p>',
  md        => 'Welcome to the site!',
  author_id => $admin->user_id,
});

my $about = $schema->resultset('Page')->create({
  name      => 'about',
  title     => 'About Me',
  html      => '<p>Some really cool stuff about me</p>',
  md        => 'Some really cool stuff about me',
  author_id => $admin->user_id,
});

$schema->resultset('Menu')->create({
  name => 'main',
  list => $json->encode( [ $about->page_id ] ), 
});

$schema;
