use Mojo::Base -strict;

use Galileo::DB::Deploy;

use Test::More;
use Test::Mojo;

my $t = Galileo::DB::Deploy->create_test_object({test => 1});
$t->ua->max_redirects(2);

subtest 'Anonymous User' => sub {

  # landing page
  $t->get_ok('/')
    ->status_is(200)
    ->text_is( h1 => 'Galileo CMS' )
    ->text_is( h2 => 'Welcome to your Galileo CMS site!' )
    ->content_like( qr/very modern/ )
    ->element_exists( 'form#login' )
    ->element_exists_not( '#user-menu' );

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
  $t->post_ok( '/login' => form => {from => '/page/home', username => 'wronguser', password => 'pass' } )
    ->status_is(200)
    ->content_like( qr/Sorry try again/ )
    ->element_exists( 'form#login' )
    ->element_exists_not( '#user-menu' );

  # fail password
  $t->post_ok( '/login' => form => {from => '/page/home', username => 'admin', password => 'wrongpass' } )
    ->status_is(200)
    ->content_like( qr/Sorry try again/ )
    ->element_exists( 'form#login' )
    ->element_exists_not( '#user-menu' );

  # successfully login
  $t->post_ok( '/login' => form => {from => '/page/home', username => 'admin', password => 'pass' } )
    ->status_is(200)
    ->content_like( qr/Welcome Back/ )
    ->element_exists_not( 'form#login' )
    ->text_like( '#user-menu li' => qr/Hello admin/ )
    ->element_exists( '#page-modal #new-page-link' )
    ->element_exists( '#user-modal #new-username' );

};

subtest 'Edit Page' => sub {

  # page editor
  $t->get_ok('/edit/home')
    ->status_is(200)
    ->text_like( '#wmd-input' => qr/Welcome to your Galileo CMS site!/ )
    ->element_exists( '#wmd-preview' );

  # save page
  my $text = 'I changed this text ☃';
  my $data = {
    name  => 'home',
    title => 'New Home',
    html  => "<p>$text</p>",
    md    => $text,
  };
  $t->websocket_ok( '/store/page' )
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # see that the changes are reflected
  $t->get_ok('/page/home')
    ->status_is(200)
    ->text_is( h1 => 'New Home' )
    ->text_like( '#content p' => qr/$text/ );

  # save page without title (error)
  my $data_notitle = {
    name  => 'notitle',
    title => '',
    html  => '<p>Hmmm no title</p>',
    md    => 'Hmmm no title',
  };
  $t->websocket_ok( '/store/page' )
    ->send_ok({ json => $data_notitle })
    ->message_ok
    ->json_message_is( { success => 0, message => 'Not saved! A title is required!' } )
    ->finish_ok;

};

subtest 'New Page' => sub {

  # author request non-existant page => create new page
  $t->get_ok('/page/doesntexist')
    ->status_is(200)
    ->text_like( '#wmd-input' => qr/Hello World/ )
    ->element_exists( '#wmd-preview' );

  # save page
  my $text = 'Today it snowed so ☃ gets a new home';
  my $data = {
    name  => 'snow❄flake',
    title => 'New Home for ☃',
    html  => "<p>$text</p>",
    md    => $text,
  };
  $t->websocket_ok( '/store/page' )
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # see that the changes are reflected
  $t->get_ok('/page/snow❄flake')
    ->status_is(200)
    ->text_is( h1 => 'New Home for ☃' )
    ->text_like( '#content p' => qr/$text/ );

};

subtest 'Edit Main Navigation Menu' => sub {
  my $title = 'About Galileo';

  # check about page is in nav 
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->text_is( 'ul#main > li:nth-of-type(4) > a' => $title )
    ->text_is( '#list-active-pages > #pages-2 > span' => $title );

  # remove about page from list
  my $data = {
    name => 'main',
    list => [],
  };
  $t->websocket_ok('/store/menu')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # check that item is removed
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->element_exists_not( 'ul#main > li:nth-of-type(3) > a' )
    ->text_is( '#list-inactive-pages > #pages-2 > span' => $title );

  # put about page back
  $data = {
    name => 'main',
    list => ['pages-3', 'pages-2'],
  };
  $t->websocket_ok('/store/menu')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # check about page is back in nav (same as first test block)
  $t->get_ok('/admin/menu')
    ->status_is(200)
    ->text_is( 'ul#main > li:nth-of-type(4) > a' => $title )
    ->text_is( '#list-active-pages > #pages-2 > span' => $title );

};

subtest 'Administrative Overview: All Users' => sub {

  # test the admin pages
  $t->get_ok('/admin/users')
    ->status_is(200)
    ->text_is( h1 => 'Administration: Users' )
    ->text_is( 'tr > td:nth-of-type(2)' => 'admin' )
    ->text_is( 'tr > td:nth-of-type(3)' => 'Joe Admin' );

};

subtest 'Administrative Overview: All Pages' => sub {

  $t->get_ok('/admin/pages')
    ->status_is(200)
    ->text_is( h1 => 'Administration: Pages' )
    ->text_is( 'tr > td:nth-of-type(2)' => 'home' );

  # attempt to remove home page
  $t->websocket_ok('/remove/page')
    ->send_ok({ json => {id => 1} })
    ->message_ok
    ->json_message_is( { success => 0, message => 'Cannot remove home page' } )
    ->finish_ok;

  # attempt to remove invalid page
  $t->websocket_ok('/remove/page')
    ->send_ok({ json => {id => 5} })
    ->message_ok
    ->json_message_is( { success => 0, message => 'Could not access page (id 5)' } )
    ->finish_ok;

  # remove page
  $t->websocket_ok('/remove/page')
    ->send_ok({ json => {id => 2} })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Page removed' } )
    ->finish_ok;

};

subtest 'Administer Users' => sub {

  $t->get_ok('/admin/user/admin')
    ->status_is(200)
    ->element_exists( 'input#name[placeholder=admin]' )
    ->element_exists( 'input#full[value="Joe Admin"]' )
    ->element_exists( 'input#is_author[checked=1]' )
    ->element_exists( 'input#is_admin[checked=1]' );

  # change name
  my $data = {
    name => "admin",
    full => "New Name",
    is_author => 1,
    is_admin => 1,
  };
  $t->websocket_ok('/store/user')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # check that the name change is reflected
  $t->get_ok('/admin/user/admin')
    ->status_is(200)
    ->element_exists( 'input#name[placeholder=admin]' )
    ->element_exists( 'input#full[value="New Name"]' );

  # attempt to change password, incorrectly
  $data = {
    name => "admin",
    full => "New Name",
    pass1 => 'newpass',
    pass2 => 'wrongpass',
    is_author => 1,
    is_admin => 1,
  };
  $t->websocket_ok('/store/user')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 0, message => 'Not saved! Passwords do not match' } )
    ->finish_ok;

  ok( $t->app->get_user('admin')->check_password('pass'), 'Password not changed on non-matching passwords');

  # change password, correctly
  $data = {
    name => "admin",
    full => "New Name",
    pass1 => 'newpass',
    pass2 => 'newpass',
    is_author => 1,
    is_admin => 1,
  };
  $t->websocket_ok('/store/user')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  ok( $t->app->get_user('admin')->check_password('newpass'), 'New password checks out');

};

subtest 'Create New User' => sub {

  # attempt to create a user without providing a password (fails)
  my $data = {
    name => "someone",
    full => "Jane ☃ Dow",
    is_author => 1,
    is_admin => 0,
  };
  $t->websocket_ok('/store/user')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 0, message => 'Cannot create user without a password' } )
    ->finish_ok;

  # create a user
  $data = {
    name => "someone",
    full => "Jane ☃ Doe",
    pass1 => 'mypass',
    pass2 => 'mypass',
    is_author => 1,
    is_admin => 0,
  };
  $t->websocket_ok('/store/user')
    ->send_ok({ json => $data })
    ->message_ok
    ->json_message_is( { success => 1, message => 'Changes saved' } )
    ->finish_ok;

  # check the new user
  $t->get_ok('/admin/user/someone')
    ->status_is(200)
    ->element_exists( 'input#name[placeholder=someone]' )
    ->element_exists( 'input#full[value="Jane ☃ Doe"]' )
    ->element_exists( 'input#is_author:checked' )
    ->element_exists( 'input#is_admin:not(:checked)' );

};

subtest 'Extra CSS/JS' => sub {
  my $app = $t->app;
  local $app->config->{extra_css} = ['mytest.css'];
  local $app->config->{extra_js}  = ['mytest.js' ];
  $t->get_ok('/')
    ->status_is(200)
    ->element_exists( 'link[href=mytest.css]' )
    ->element_exists( 'script[src=mytest.js]' );
};

subtest 'Logging Out' => sub {
  # This is essentially a repeat of the first test
  $t->get_ok('/logout')
    ->status_is(200)
    ->text_is( h1 => 'New Home' )
    ->element_exists( 'form' );
};

done_testing();

