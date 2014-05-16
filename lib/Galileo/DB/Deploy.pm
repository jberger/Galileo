package Galileo::DB::Deploy;
use Moose;
BEGIN{ extends 'DBIx::Class::DeploymentHandler' }

# A wrapper class for DBICDH for use with Galileo

use Mojo::JSON 'j';;

use File::ShareDir qw/dist_dir/;
use File::Spec;
use File::Temp ();
use File::Copy::Recursive 'dircopy';

has 'temp_script_dir' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_temp_script_dir',
);

sub _build_temp_script_dir {
  File::Temp->newdir( $ENV{KEEP_TEMP_DIR} ? (CLEANUP => 0) : () );
}

has 'real_script_dir' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_real_script_dir',
);

sub _build_real_script_dir {
  my $dev_dir = File::Spec->catdir( qw/ lib Galileo files sql / );
  -e $dev_dir ? $dev_dir : File::Spec->catdir( dist_dir('Galileo'), 'sql' );
}

has 'script_directory' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_script_directory',
);

sub _build_script_directory {
  my $self = shift;
  my $dir  = $self->real_script_dir;
  my $temp = $self->temp_script_dir;
  dircopy $dir, $temp or die "Cannot copy from $dir to $temp";
  return "$temp";
}

has 'databases' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_databases',
);

sub _build_databases { [ shift->schema->storage->sqlt_type ] }

has '+force_overwrite' => (
  default => 1,
);

has '+ignore_ddl' => (
  default => 1,
);

sub installed_version {
  my $self = shift;
  return eval{ $self->database_version }
}

sub setup_unversioned {
  my $self = shift;

  unless ( $self->version_storage_is_installed ) {
    $self->prepare_version_storage_install;
    $self->install_version_storage;
  }

  $self->add_database_version({ version => 1 });

  return 1;
}

sub do_install {
  my $self = shift;

  $self->prepare_install;
  $self->install;
}

sub do_upgrade {
  my $self = shift;

  $self->prepare_upgrade;
  $self->upgrade;
}

sub has_admin_user {
  my $self = shift;
  return eval { $self->schema->resultset('User')->first }
}

sub inject_sample_data {
  my $self = shift;
  my $schema = $self->schema;

  my $user = shift or die "Must provide an admin username\n";
  my $pass = shift or die "Must provide a password for admin user\n";
  my $full = shift || "Administrator";

  my $admin = $schema->resultset('User')->create({
    name => $user,
    full => $full,
    password => $pass,
    is_author => 1,
    is_admin  => 1,
  });

  $schema->resultset('Page')->create({
    name      => 'home',
    title     => 'Galileo CMS',
    html      => <<'HTML',
<h2>Welcome to your Galileo CMS site!</h2>

<blockquote>
  <p>Galileo Galilei was "an Italian physicist, mathematician, astronomer, and philosopher who played a major role in the Scientific Revolution." -- <a href="https://en.wikipedia.org/wiki/Galileo_Galilei">Wikipedia</a> </p>
</blockquote>

<p>When he first turned the telescope to face Jupiter, he used modern technology to improve the world around him.</p>

<p>Like the great scientist it is named for, Galileo CMS is not afraid to be very modern. Learn more about it on the <a href="/page/about">about</a> page.</p>

<p><img src="/portrait.jpg" alt="Portrait of Galileo Galilei" title="" /></p>
HTML
    md        => <<'MARKDOWN',
##Welcome to your Galileo CMS site!

> Galileo Galilei was "an Italian physicist, mathematician, astronomer, and philosopher who played a major role in the Scientific Revolution." -- [Wikipedia](https://en.wikipedia.org/wiki/Galileo_Galilei) 

When he first turned the telescope to face Jupiter, he used modern technology to improve the world around him.

Like the great scientist it is named for, Galileo CMS is not afraid to be very modern. Learn more about it on the [about](/page/about) page.

![Portrait of Galileo Galilei](/portrait.jpg)
MARKDOWN
    author_id => $admin->user_id,
  });

  my $about = $schema->resultset('Page')->create({
    name      => 'about',
    title     => 'About Galileo',
    html      => <<'HTML',
<p>Galileo CMS is built upon some great open source projects:</p>

<ul>
<li><a href="http://perl.org">Perl</a> - if you haven't looked at Perl lately, give it another try!</li>
<li><a href="http://mojolicio.us">Mojolicious</a> - a next generation web framework for the Perl programming language</li>
<li><a href="http://www.dbix-class.org/">DBIx::Class</a> - an extensible and flexible Object/Relational Mapper written in Perl</li>
<li><a href="http://code.google.com/p/pagedown/">PageDown</a> (Markdown engine) - the version of Attacklab's Showdown and WMD as used on Stack Overflow and the other Stack Exchange sites</li>
<li><a href="http://twitter.github.com/bootstrap">Bootstrap</a> - the beautiful CSS/JS library from Twitter</li>
<li><a href="http://jquery.com/">jQuery</a> - because everything uses jQuery</li>
<li><a href="http://wavded.github.com/humane-js/">HumaneJS</a> - A simple, modern, browser notification system</li>
</ul>

<p>Galileo is developed by <a href="https://github.com/jberger">Joel Berger</a>. <a href="https://github.com/jberger/Galileo">Fork it</a> on GitHub!</p>
HTML
    md        => <<'MARKDOWN',
Galileo CMS is built upon some great open source projects:

* [Perl](http://perl.org) - if you haven't looked at Perl lately, give it another try!
* [Mojolicious](http://mojolicio.us) - a next generation web framework for the Perl programming language
* [DBIx::Class](http://www.dbix-class.org/) - an extensible and flexible Object/Relational Mapper written in Perl
* [PageDown](http://code.google.com/p/pagedown/) (Markdown engine) - the version of Attacklab's Showdown and WMD as used on Stack Overflow and the other Stack Exchange sites
* [Bootstrap](http://twitter.github.com/bootstrap) - the beautiful CSS/JS library from Twitter
* [jQuery](http://jquery.com/) - because everything uses jQuery
* [HumaneJS](http://wavded.github.com/humane-js/) - A simple, modern, browser notification system

Galileo is developed by [Joel Berger](https://github.com/jberger). [Fork it](https://github.com/jberger/Galileo) on GitHub!
MARKDOWN
    author_id => $admin->user_id,
  });

  my $syntax = $schema->resultset('Page')->create({
    name      => 'syntax',
    title     => 'Syntax',
    html      => <<'HTML',
<h2>Highlighting</h2>

<p>Default highlighter is <a href="http://highlightjs.org/">highlight.js</a>. But Galileo just generates HTML so if you want to see colorized output then you have to load javascript and css.</p>

<pre class="hljs"><code class="language-xml">&lt;!-- example --&gt;
&lt;link rel="stylesheet" href="http://yandex.st/highlightjs/8.0/styles/default.min.css"&gt;
&lt;script src="http://yandex.st/highlightjs/8.0/highlight.min.js"&gt;&lt;/script&gt;
&lt;script&gt; (fuction () { hljs.initHighlightingOnLoad(); })(); &lt;/script&gt;</code></pre>

<h2>Tables</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code class="language-markdown">| Item      | Value | Qty |
| --------- | -----:|:--: |
| Computer  | $1600 | 5   |
| Phone     |   $12 | 12  |
| Pipe      |    $1 |234  |</code></pre>

<p><em>result</em>:</p>

<table class="table table-striped">
<thead>
<tr>
  <th>Item</th>
  <th style="text-align:right;">Value</th>
  <th style="text-align:center;">Qty</th>
</tr>
</thead>
<tr>
  <td>Computer</td>
  <td style="text-align:right;">$1600</td>
  <td style="text-align:center;">5</td>
</tr>
<tr>
  <td>Phone</td>
  <td style="text-align:right;">$12</td>
  <td style="text-align:center;">12</td>
</tr>
<tr>
  <td>Pipe</td>
  <td style="text-align:right;">$1</td>
  <td style="text-align:center;">234</td>
</tr>
</table>


<h2>Fenced Code Blocks</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code>```perl
#!/usr/bin/env perl

use strict;
use warnings;
use Galileo;
```
</code></pre>

<p><em>result</em>:</p>

<pre class="hljs"><code class="language-perl">#!/usr/bin/env perl

use strict;
use warnings;
use Galileo;</code></pre>

<h2>Definition Lists</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code>Term 1
:   Definition 1

Term 2
:   This definition has a code block.

        code block</code></pre>

<p><em>result</em>:</p>

<dl>
<dt>Term 1</dt>
<dd>Definition 1</dd>

<dt>Term 2</dt>
<dd>
<p>This definition has a code block.</p>

<pre class="hljs"><code>code block
</code></pre>
</dd>
</dl>

<h2>Special Attributes</h2>

<p>You can add class and id attributes to headers and gfm fenced code blocks.</p>

<p><em>source</em>:</p>

<pre class="hljs"><code>``` {#gfm-id .gfm-class}
var foo = bar;
```

## A Header {#header-id}

### Another One ### {#header-id .hclass}

Underlined  {#what}
==========
</code></pre>

<p><em>result</em>:</p>

<pre class="hljs"><code class="language-html">&lt;pre id="gfm-id" class="gfm-class prettyprint"&gt;&lt;code&gt;var foo = bar;&lt;/code&gt;&lt;/pre&gt;

&lt;h2 id="header-id"&gt;A Header&lt;/h2&gt;

&lt;h3 id="header-id" class="hclass"&gt;Another One&lt;/h3&gt;

&lt;h1 id="what"&gt;Underlined &lt;/h1&gt;</code></pre>

<h2>Footnotes</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code>Here is a footnote which will be located at the end of the page[^footnote].

[^footnote]: Here is the *text* of the **footnote**.</code></pre>

<p><em>result</em>:</p>

<p>Here is a footnote which will be located at the end of the page<a href="#fn:footnote" id="fnref:footnote" title="See footnote" class="footnote">1</a>.</p>

<h2>SmartyPants</h2>

<p>SmartyPants extension converts ASCII punctuation characters into &#8220;smart&#8221; typographic punctuation HTML entities.</p>

<table class="table table-striped">
<thead>
<tr>
  <th></th>
  <th>ASCII</th>
  <th>HTML</th>
</tr>
</thead>
<tr>
  <td>Single backticks</td>
  <td><code>'Isn't this fun?'</code></td>
  <td>&#8216;Isn&#8217;t this fun?&#8217;</td>
</tr>
<tr>
  <td>Quotes</td>
  <td><code>"Isn't this fun?"</code></td>
  <td>&#8220;Isn&#8217;t this fun?&#8221;</td>
</tr>
<tr>
  <td>Dashes</td>
  <td><code>This -- is an en-dash and this --- is an em-dash</code></td>
  <td>This &#8211; is an en-dash and this &#8212; is an em-dash</td>
</tr>
</table>


<h2>Newlines</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code>Roses are red
Violets are blue</code></pre>

<p><em>result</em>:</p>

<p>Roses are red <br>
Violets are blue</p>

<h2>Strikethrough</h2>

<p><em>source</em>:</p>

<pre class="hljs"><code>~~Mistaken text.~~</code></pre>

<p><em>result</em>:</p>

<p><del>Mistaken text.</del></p>

<div class="footnotes">
<hr>
<ol>

<li id="fn:footnote">Here is the <em>text</em> of the <strong>footnote</strong>. <a href="#fnref:footnote" title="Return to article" class="reversefootnote">&#8617;</a></li>

</ol>
</div>
</div>
HTML
    md        => <<'MARKDOWN',
## Highlighting

Default highlighter is [highlight.js](http://highlightjs.org/). But Galileo just generates HTML so if you want to see colorized output then you have to load javascript and css.

```xml
<!-- example -->
<link rel="stylesheet" href="http://yandex.st/highlightjs/8.0/styles/default.min.css">
<script src="http://yandex.st/highlightjs/8.0/highlight.min.js"></script>
<script> (fuction () { hljs.initHighlightingOnLoad(); })(); </script>
```

## Tables

*source*:

```markdown
| Item      | Value | Qty |
| --------- | -----:|:--: |
| Computer  | $1600 | 5   |
| Phone     |   $12 | 12  |
| Pipe      |    $1 |234  |
```

*result*:

| Item      | Value | Qty |
| --------- | -----:|:--: |
| Computer  | $1600 | 5   |
| Phone     |   $12 | 12  |
| Pipe      |    $1 |234  |


##  Fenced Code Blocks

*source*:

    ```perl
    #!/usr/bin/env perl

    use strict;
    use warnings;
    use Galileo;
    ```

*result*:

```perl
#!/usr/bin/env perl

use strict;
use warnings;
use Galileo;
```

##  Definition Lists

*source*:

```
Term 1
:   Definition 1

Term 2
:   This definition has a code block.

        code block
```

*result*:

Term 1
:   Definition 1

Term 2
:   This definition has a code block.

        code block

## Special Attributes

You can add class and id attributes to headers and gfm fenced code blocks.

*source*:

    ``` {#gfm-id .gfm-class}
    var foo = bar;
    ```

    ## A Header {#header-id}

    ### Another One ### {#header-id .hclass}

    Underlined  {#what}
    ==========

*result*:

```html
<pre id="gfm-id" class="gfm-class prettyprint"><code>var foo = bar;</code></pre>

<h2 id="header-id">A Header</h2>

<h3 id="header-id" class="hclass">Another One</h3>

<h1 id="what">Underlined </h1>
```

## Footnotes

*source*:

```
Here is a footnote which will be located at the end of the page[^footnote].

[^footnote]: Here is the *text* of the **footnote**.
```

*result*:

Here is a footnote which will be located at the end of the page[^footnote].

[^footnote]: Here is the *text* of the **footnote**.

## SmartyPants

SmartyPants extension converts ASCII punctuation characters into "smart" typographic punctuation HTML entities.

|                  | ASCII                                              | HTML                                |
 ------------------|----------------------------------------------------|-------------------------------------
| Single backticks | `'Isn't this fun?'`                                | &#8216;Isn&#8217;t this fun?&#8217; |
| Quotes           | `"Isn't this fun?"`                                | &#8220;Isn&#8217;t this fun?&#8221; |
| Dashes           | `This -- is an en-dash and this --- is an em-dash` | This &#8211; is an en-dash and this &#8212; is an em-dash |

## Newlines

*source*:

```
Roses are red
Violets are blue
```

*result*:

Roses are red
Violets are blue

## Strikethrough

*source*:

```
~~Mistaken text.~~
```

*result*:

~~Mistaken text.~~
MARKDOWN
    author_id => $admin->user_id,
  });

  $schema->resultset('Menu')->create({
    name => 'main',
    list => j( [ $syntax->page_id, $about->page_id ] ),
  });
}

sub create_test_object {
  my $class = shift;
  my $opts = ref $_[-1] eq 'HASH' ? pop : {};

  require Galileo;
  require Galileo::DB::Schema;

  my $db = Galileo::DB::Schema->connect('dbi:SQLite:dbname=:memory:','','',{sqlite_unicode=>1});

  my $dh = __PACKAGE__->new(
    databases => [],
    schema => $db,
  );
  $dh->do_install;
  $dh->inject_sample_data('admin', 'pass', 'Joe Admin');
  

  if ($opts->{test}) {
    require Test::More;
    Test::More::ok( 
      $db->resultset('User')->single({name => 'admin'})->check_password('pass'), 
      'DB user checks out'
    );
    Test::More::ok( $dh->installed_version, 'Found version information' );
  }

  require Test::Mojo;
  my $t = Test::Mojo->new(Galileo->new(db => $db));

  return wantarray ? ($t, $dh) : $t;
}

1;

