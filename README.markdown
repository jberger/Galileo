This is my first attempt at a Perl CMS using Mojolicious, Bootstrap, Pagedown and DBIx::Class/SQLite.

It uses client-side markdown rendering and websockets for saving page data without reloading.

To start you will need to install a few Perl modules.

* Mojolicious
* SQLite
* DBIx::Class
* SQL::Translator

After that, in order to create the database, simply run

    $ ./bin/create_db.pl

which will create the sqlite database file in the root of the distribution.

From there start the server by running

    morbo myapp.pl

you should now be able to visit the site at [localhost:3000](http://localhost:3000).

This is by no means a complete project, any comments/pull requests are welcome.

MojoCMS is copyright 2012 Joel Berger
MojoCMS is released under the same terms as Perl (Artistic 2.0)

