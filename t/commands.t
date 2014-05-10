use utf8;
use Mojo::Base -strict;

use Galileo::DB::Deploy;

use Test::More;
use Test::Mojo;

use Mojolicious::Commands;
use Encode qw( encode decode );
use File::Spec;
use File::Temp ();

# dump
subtest 'Dump' => sub {
  # methods
  require Galileo::Command::dump;
  my $dump = Galileo::Command::dump->new;
  ok $dump->description, 'has a description';
  like $dump->usage, qr/dump/, 'has usage information';

  # ready to test
  my $dir = File::Temp->newdir( $ENV{KEEP_TEMP_DIR} ? (CLEANUP => 0) : () );
  my $t   = Galileo::DB::Deploy->create_test_object({test => 1});
  isa_ok $t->app, 'Galileo';

  # test sample pages
  {
    # dump
    $t->app->start('dump', "--directory=$dir", '--title=<!-- %s -->');

    my %pages = (
      about => {
        title   => 'About Galileo',
        content => qr/Galileo CMS is built upon some great open source projects:/,
      },
      home => {
        title   => 'Galileo CMS',
        content => qr/##Welcome to your Galileo CMS site!/,
      },
    );
    for my $name ( keys %pages ) {
      my $file = File::Spec->catfile( $dir, "$name.md" );
      ok -e $file, "sample data: $name - exists";
      open my $fh, '<', $file or die "cannot open $file: $!";
      my $content = do { local $/; <$fh> };
      close $fh;
      like $content, qr/\A<!-- $pages{$name}{title} -->/, "sample data: $name - title";
      like $content, $pages{$name}{content}, "sample data: $name - content";
    }
  }

  # add utf-8 page
  {
    $t->ua->max_redirects(2);

    $t->get_ok('/page/doesntexist')
      ->status_is(404);

    # successfully login
    $t->post_ok( '/login' => form => {from => '/page/home', username => 'admin', password => 'pass' } )
      ->status_is(200)
      ->content_like( qr/Welcome Back/ )
      ->element_exists_not( 'form#login' )
      ->text_like( '#user-menu li' => qr/Hello admin/ )
      ->element_exists( '#page-modal #new-page-link' )
      ->element_exists( '#user-modal #new-username' );

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
  }

  # dump sample pages and brand new utf-8 page
  {
    $t->app->start('dump', "--directory=$dir", '--title=<!-- %s -->', '--encoding=utf-8');

    my %pages = (
      about => {
        title   => 'About Galileo',
        content => qr/Galileo CMS is built upon some great open source projects:/,
      },
      home => {
        title   => 'Galileo CMS',
        content => qr/##Welcome to your Galileo CMS site!/,
      },
      'snow❄flake' => {
        title   => 'New Home for ☃',
        content => qr/Today it snowed so ☃ gets a new home/,
      },
    );
    for my $name ( keys %pages ) {
      my $encoded_name = encode('utf-8', $name);
      my $file         = File::Spec->catfile( $dir, "$name.md" );
      ok -e $file, "sample data: $encoded_name - exists";
      open my $fh, '<', $file or die "cannot open $file: $!";
      my $content = do { local $/; <$fh> };
      my $decoded_content = decode('utf-8', $content);
      close $fh;
      like $decoded_content, qr/\A<!-- $pages{$name}{title} -->/, "sample data: $encoded_name - title";
      like $decoded_content, $pages{$name}{content}, "sample data: $encoded_name - content";
    }
  }
};

done_testing();
