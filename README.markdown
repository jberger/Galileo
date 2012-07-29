Galileo CMS is my first attempt at a Perl CMS using Mojolicious, Bootstrap, Pagedown and DBIx::Class/SQLite.

It uses client-side markdown rendering and websockets for saving page data without reloading.

To start you will need to install a few Perl modules. Do so by installing the dependencies specified in the file `Build.PL`. If you have `cpanm` this is as easy as

    $ cpanm --installdeps .

If you don't have `cpanm` (and you should), you may

    $ perl Build.PL
    $ ./Build installdeps

After that, in order to create the database, simply run

    $ ./script/galileo create_database

which will create the sqlite database file in the root of the distribution. In the process it will ask for a username and password for your admin user. This password is no longer stored in clear text!

From there start the server by running

    $ morbo script/galileo

you should now be able to visit the site at [localhost:3000](http://localhost:3000).

This is by no means a complete project, any comments/pull requests are welcome.

Galileo CMS is copyright 2012 Joel Berger

Galileo CMS is released under the same terms as Perl (Artistic 2.0)

