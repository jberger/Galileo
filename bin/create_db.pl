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

