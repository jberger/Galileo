use strict;
use warnings;

use Test::More;
use Test::Mojo;

use Mojolicious::Lite;

plugin 'Galileo::Plugin::Modal';

any '/' => 'index';

my $t = Test::Mojo->new;

$t->get_ok('/')
  ->status_is(200)
  ->text_is('#id.modal .modal-body p' => 'hi');

done_testing;

__DATA__

@@ index.html.ep
%= modal id => 'hi'

