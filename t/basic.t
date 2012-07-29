use strict;
use warnings;

use Galileo;
use Galileo::DB::Schema;
use Galileo::Command::setup;

use Mojo::JSON;
use Test::More;
END{ done_testing(); }

use Test::Mojo;

my $db = Galileo::DB::Schema->connect('dbi:SQLite:dbname=:memory:');
Galileo::Command::setup->inject_sample_data('admin', 'pass', $db);
ok( $db->resultset('User')->single({name => 'admin'})->check_password('pass'), 'DB user checks out' );

my $t = Test::Mojo->new(Galileo->new(db => $db));
$t->ua->max_redirects(2);

subtest 'Anonymous User' => sub {

  # landing page
  $t->get_ok('/')
    ->status_is(200)
    ->text_is( h1 => 'Galileo CMS' )
    ->text_is( h2 => 'Welcome to your Galileo CMS site!' )
    ->text_like( p => qr/modern CMS/ )
    ->element_exists( 'form' );

  # attempt to get non-existant page
  $t->get_ok('/page/doesntexist')
    ->status_is(404);

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

};

subtest 'Do Login' => sub {

  # fail username
  $t->post_form_ok( '/login' => {from => '/page/home', username => 'wronguser', password => 'pass' } )
    ->status_is(200)
    ->content_like( qr/Sorry try again/ )
    ->element_exists( 'form' );

  # fail password
  $t->post_form_ok( '/login' => {from => '/page/home', username => 'admin', password => 'wrongpass' } )
    ->status_is(200)
    ->content_like( qr/Sorry try again/ )
    ->element_exists( 'form' );

  # successfully login
  $t->post_form_ok( '/login' => {from => '/page/home', username => 'admin', password => 'pass' } )
    ->status_is(200)
    ->content_like( qr/Welcome Back/ )
    ->text_like( '#user-menu li' => qr/Hello admin/ );

};

subtest 'Edit Page' => sub {

  # page editor
  $t->get_ok('/edit/home')
    ->status_is(200)
    ->text_like( '#wmd-input' => qr/Welcome to your Galileo CMS site!/ )
    ->element_exists( '#wmd-preview' );

  # save page
  my $text = 'I changed this text';
  my $json = Mojo::JSON->new->encode({
    name  => 'home',
    title => 'New Home',
    html  => "<p>$text</p>",
    md    => $text,
  });
  $t->websocket_ok( '/store/page' )
    ->send_ok( $json )
    ->message_is( 'Changes saved' )
    ->finish_ok;

  # see that the changes are reflected
  $t->get_ok('/page/home')
    ->status_is(200)
    ->text_is( h1 => 'New Home' )
    ->text_like( p => qr/$text/ );

  # author request non-existant page => create new page
  $t->get_ok('/page/doesntexist')
    ->status_is(200)
    ->text_like( '#wmd-input' => qr/Hello World/ )
    ->element_exists( '#wmd-preview' );

  # save page without title (error)
  my $json_notitle = Mojo::JSON->new->encode({
    name  => 'notitle',
    title => '',
    html  => '<p>Hmmm no title</p>',
    md    => 'Hmmm no title',
  });
  $t->websocket_ok( '/store/page' )
    ->send_ok( $json_notitle )
    ->message_is( 'Not saved! A title is required!' )
    ->finish_ok;

};

subtest 'Edit Main Navigation Menu' => sub {
  my $title = 'About Galileo';

  # check about page is in nav 
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->text_is( 'ul#main > li:nth-of-type(3) > a' => $title )
    ->text_is( '#list-active-pages > #pages-2 > span' => $title );

  # remove about page from list
  my $json = Mojo::JSON->new->encode({
    name => 'main',
    list => [],
  });
  $t->websocket_ok('/store/menu')
    ->send_ok( $json )
    ->message_is( 'Changes saved' )
    ->finish_ok;

  # check that item is removed
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->element_exists_not( 'ul#main > li:nth-of-type(3) > a' )
    ->text_is( '#list-inactive-pages > #pages-2 > span' => $title );

  # put about page back
  $json = Mojo::JSON->new->encode({
    name => 'main',
    list => ['pages-2'],
  });
  $t->websocket_ok('/store/menu')
    ->send_ok( $json )
    ->message_is( 'Changes saved' )
    ->finish_ok;

  # check about page is back in nav (same as first test block)
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->text_is( 'ul#main > li:nth-of-type(3) > a' => $title )
    ->text_is( '#list-active-pages > #pages-2 > span' => $title );

};

subtest 'Administrative Overview Pages' => sub {

  # test the admin pages
  $t->get_ok('/admin/users')
    ->status_is(200)
    ->text_is( h1 => 'Administration: Users' )
    ->text_is( 'tr > td:nth-of-type(2)' => 'admin' );

  $t->get_ok('/admin/pages')
    ->status_is(200)
    ->text_is( h1 => 'Administration: Pages' )
    ->text_is( 'tr > td:nth-of-type(2)' => 'home' );

};

subtest 'Logging Out' => sub {
  # This is essentially a repeat of the first test
  $t->get_ok('/logout')
    ->status_is(200)
    ->text_is( h1 => 'New Home' )
    ->element_exists( 'form' );
};

