use Mojo::Base -strict;

use Mojo::JSON 'j';
use File::Spec;
use Galileo::DB::Deploy;

use Test::More;
use Test::Mojo;

my $home = $ENV{GALILEO_HOME} = File::Spec->catdir( qw/ t locations / );

my $t = Galileo::DB::Deploy->create_test_object({ test => 1 });
my $app = $t->app;

is( $app->home, $home, 'home dir detected from GALILEO_HOME' );

$t->get_ok('/test.html')
  ->status_is(200)
  ->text_is('body' => 'test text')
  ->or( sub { diag "'static' should be in @{ $app->static->paths }" } );

# login
$t->post_ok( '/login' => form => {from => '/page/home', username => 'admin', password => 'pass' } );

$t->websocket_ok('/files/list')
  ->send_ok({ text => j({limit => 0}) })
  ->message_ok
  ->json_message_is( '/' => { files => [sort 'image1.jpg', 'img/image2.jpg'], finished => 1 })
  ->finish_ok;

done_testing();

