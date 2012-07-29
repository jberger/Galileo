use strict;
use warnings;

use MojoCMS;

use Mojo::JSON;
use Test::More;
END{ done_testing(); }

use Test::Mojo;

my $db = do 't/database.pl';
ok( $db->resultset('User')->single({name => 'admin'})->check_password('pass'), 'DB user checks out' );

my $t = Test::Mojo->new(MojoCMS->new(db => $db));
$t->ua->max_redirects(2);

## Not logged in ##

# landing page
$t->get_ok('/pages/home')
  ->status_is(200)
  ->text_is( h1 => 'Home Page' )
  ->text_like( p => qr/Welcome to the site!/ )
  ->element_exists( 'form' );

# attempt to edit page
$t->get_ok('/edit/home')
  ->status_is(200)
  ->content_like( qr/Not Authorized/ );

# attempt to menu admin page
$t->get_ok('/admin/menu')
  ->status_is(200)
  ->content_like( qr/Not Authorized/ );

# attempt to user admin page
$t->get_ok('/admin/users')
  ->status_is(200)
  ->content_like( qr/Not Authorized/ );

## Logged in ##

# do login
$t->post_form_ok( '/login' => {from => '/pages/home', username => 'admin', password => 'pass' } )
  ->status_is(200)
  ->content_like( qr/Welcome Back/ )
  ->text_like( '#user-menu li' => qr/Hello admin/ );

# page editor
$t->get_ok('/edit/home')
  ->status_is(200)
  ->text_like( '#wmd-input' => qr/Welcome to the site!/ )
  ->element_exists( '#wmd-preview' );

# save page
my $json = Mojo::JSON->new->encode({
  store => "pages",
  name  => 'home',
  title => 'New Home',
  html  => '<p>I changed this text</p>',
  md    => 'I changed this text',
});
$t->websocket_ok( '/store/page' )
  ->send_ok( $json )
  ->message_is( 'Changes saved' )
  ->finish_ok;

# see that the changes are reflected
$t->get_ok('/pages/home')
  ->status_is(200)
  ->text_is( h1 => 'New Home' )
  ->text_like( p => qr/I changed this text/ );

# test the admin pages
$t->get_ok('/admin/users')
  ->status_is(200)
  ->text_is( h1 => 'Administration: Users' )
  ->text_is( 'tr > td:nth-of-type(2)' => 'admin' );

$t->get_ok('/admin/pages')
  ->status_is(200)
  ->text_is( h1 => 'Administration: Pages' )
  ->text_is( 'tr > td:nth-of-type(2)' => 'home' );

