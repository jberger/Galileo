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
  is_author => 1,
  is_admin  => 1,
});

$schema->resultset('Page')->create({
  name      => 'home',
  title     => 'Home Page',
  html      => '<p>Welcome to the site!</p>',
  md        => 'Welcome to the site!',
  author_id => $admin->id,
});

my $about = $schema->resultset('Page')->create({
  name      => 'about',
  title     => 'About Me',
  html      => '<p>Some really cool stuff about me</p>',
  md        => 'Some really cool stuff about me',
  author_id => $admin->id,
});

$schema->resultset('Menu')->create({
  name => 'main',
  list => sprintf( '["%s"]', $about->id ), 
  html => sprintf( '<li><a href="/pages/%s">%s</a></li>', $about->name, $about->title ),
});

