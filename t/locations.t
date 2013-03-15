use Mojo::Base -strict;

use Mojo::JSON 'j';
use File::Spec;
use Galileo::DB::Deploy;

use Test::More;
use Test::Mojo;

my $home = $ENV{GALILEO_HOME} = File::Spec->rel2abs(File::Spec->catdir( qw/ t locations / ));

my $t = Galileo::DB::Deploy->create_test_object({ test => 1 });
$t->ua->max_redirects(2);
my $app = $t->app;

is( $app->home, $home, 'home dir detected from GALILEO_HOME' );

$t->get_ok('/test.html')
  ->status_is(200)
  ->text_is('body' => 'test text')
  ->or( sub { diag "'static' should be in @{ $app->static->paths }" } );

# login
$t->post_ok( '/login' => form => {from => '/page/home', username => 'admin', password => 'pass' } );

# this hack fixes windows tests, but not the underlying problem that I don't want these found files reslashed!
my $image2 = File::Spec->catfile( qw/ img image2.jpg / );
$t->websocket_ok('/files/list')
  ->send_ok({ text => j({limit => 0}) })
  ->message_ok
  ->json_message_is( '/' => { files => [sort 'image1.jpg', $image2], finished => 1 })
  ->finish_ok;

# test limited number of files found. note order is not guaranteed
$t->websocket_ok('/files/list')
  ->send_ok({ text => j({limit => 1}) })
  ->message_ok
  ->json_message_has(   '/files/0' )
  ->json_message_hasnt( '/files/1' )
  ->json_message_is( '/finished' => 0 )
  ->send_ok({ text => j({limit => 1}) })
  ->message_ok
  ->json_message_has(   '/files/0' )
  ->json_message_hasnt( '/files/1' )
  ->json_message_is( '/finished' => 0 )
  ->send_ok({ text => j({limit => 1}) })
  ->message_ok
  ->json_message_is( '/' => { files => [], finished => 1 } )
  ->finish_ok;

done_testing();

