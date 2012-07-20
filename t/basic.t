use strict;
use warnings;

use Test::More;
END{ done_testing(); }

use Test::Mojo;

my $db = do 't/database.pl';
my $t = Test::Mojo->new('MojoCMS')->app(db => $db);

$t->get_ok('/pages/home')->status_is(200)->text_is(h1 => 'Home Page');

