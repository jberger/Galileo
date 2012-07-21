use strict;
use warnings;

use MojoCMS;
use Test::More;
END{ done_testing(); }

use Test::Mojo;

my $db = do 't/database.pl';
ok( $db->resultset('User')->single({name => 'admin'})->check_password('pass') );

my $t = Test::Mojo->new(MojoCMS->new(db => $db));
$t->ua->max_redirects(2);

$t->get_ok('/pages/home')
  ->status_is(200)
  ->text_is(h1 => 'Home Page')
  ->text_like( p => qr/Welcome to the site!/ )
  ->element_exists( 'form' );

$t->post_form_ok( '/login' => {from => '/pages/home', username => 'admin', password => 'pass' } )
  ->status_is(200)
  ->content_like( qr/Welcome Back/ )
  ->content_like( qr/Hello admin/ );
