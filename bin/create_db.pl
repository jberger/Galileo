#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use MojoCMS::DB::Schema;
my $schema = MojoCMS::DB::Schema->connect('dbi:SQLite:dbname=mysqlite.db');
$schema->deploy;

my $admin = $schema->resultset('User')->create({
  name => 'joel',
  pass => 'pass',
});

$schema->resultset('Page')->create({
    name      => 'home',
    title     => 'Home Page',
    html      => '<p>Welcome to the site!</p>',
    md        => 'Welcome to the site!',
    author_id => $admin->id,
});

$schema->resultset('Page')->create({
    name      => 'about',
    title     => 'About Me',
    html      => '<p>Some really cool stuff about me</p>',
    md        => 'Some really cool stuff about me',
    author_id => $admin->id,
});

