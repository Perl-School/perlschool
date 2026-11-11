use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use File::Copy qw( copy );
use File::Temp qw( tempdir );
use Path::Tiny qw( path );

use PerlSchool::Build;

chdir "$FindBin::Bin/.." or die "Cannot enter repository root: $!";
local $ENV{PERLSCHOOL_ERRATA_FORM_URL} = '';
my $work = path(tempdir(CLEANUP => 1));
my $database = $work->child('catalogue.db');
copy('perlschool.db', $database) or die "Cannot copy catalogue: $!";
my $schema = PerlSchool::Schema->get_schema($database->stringify);
my $dbh = $schema->storage->dbh;
my $book_count = $schema->books->count;

# Exercise the upgrade from a pre-errata catalogue, independently of the
# checked-in database's migration state.
$dbh->do('DROP TABLE IF EXISTS errata');
for my $sql (split /;/, path('migrations/002-add-errata.sql')->slurp_utf8) {
  $dbh->do($sql) if $sql =~ /\S/;
}
is($schema->books->count, $book_count, 'migration preserves catalogue records');
is($schema->resultset('Erratum')->count, 0, 'migration starts with no published errata');
$dbh->do('PRAGMA foreign_keys = ON');

my $book = $schema->books->find({ slug => 'data-munging' });
my $other = $schema->books->find({ slug => 'perl-taster' });
my $empty = $schema->books->find({ slug => 'selenium-perl' });
my $entry = $book->create_related('errata', {
  description => "Page 12: use <value> & \"quotes\".\nA second line.",
});
$entry->discard_changes;
is($entry->status, 'Reported', 'new errata default to Reported');
like($entry->date_reported->ymd, qr/^\d{4}-\d{2}-\d{2}$/, 'report date defaults to a date');
is($entry->book->id, $book->id, 'erratum belongs to its book');
$entry->update({ date_reported => '2026-01-01', status => 'Fixed & <checked>' });
my $newer = $book->create_related('errata', {
  date_reported => '2026-02-01', status => 'Confirmed', description => 'A later correction.',
});
my $tie = $book->create_related('errata', {
  date_reported => '2026-02-01', description => 'Another correction on the same date.',
});
$other->create_related('errata', { description => 'Only for the other book.' });
is_deeply([map { $_->id } @{$book->errata_list}], [$tie->id, $newer->id, $entry->id],
          'errata are scoped to the book and ordered newest first with stable ties');
is_deeply($empty->errata_list, [], 'books without errata return an empty list');

ok(!eval { $book->create_related('errata', { description => '' }); 1 },
   'empty correction descriptions are rejected');
ok(!eval { $schema->resultset('Erratum')->create({book_id => -1, description => 'Orphan'}); 1 },
   'foreign key rejects errata for a nonexistent book');

my $app = PerlSchool::Build->new(schema => $schema, output_dir => $work->child('site'));
sub render_book {
  my ($feature) = @_;
  $app->make_page('book.html.tt', {
    feature => $feature, books => [],
    canonical => 'https://perlschool.com/books/' . $feature->slug . '/',
  }, 'book/index.html');
  return $work->child('site/book/index.html')->slurp_utf8;
}

my $html = render_book($book);
like($html, qr/data-bs-toggle="modal" data-bs-target="#errataModal"/, 'book has an Errata button');
like($html, qr/aria-labelledby="errataModalTitle"/, 'modal has an accessible title');
like($html, qr/<h1[^>]+id="errataModalTitle">Errata<\/h1>/, 'modal is titled Errata');
like($html, qr/<th scope="col">Date reported<\/th>/, 'table displays report dates');
like($html, qr/<time datetime="2026-01-01">01 Jan 2026<\/time>/, 'dates are formatted for readers and machines');
like($html, qr/Fixed &amp; &lt;checked&gt;/, 'published status is escaped');
like($html, qr/Page 12: use &lt;value&gt; &amp; &quot;quotes&quot;\.\nA second line\./,
     'description is escaped and retains newlines');
unlike($html, qr/Only for the other book\./, "other books' corrections are not displayed");
unlike($html, qr/No errata reported/, 'nonempty list does not show the empty message');
unlike($html, qr/<form\b/, 'no submission form without an endpoint');
unlike($html, qr/src="\/js\/errata\.js"/, 'email fallback does not load the submission script');
like($html, qr/href="mailto:hello\@perlschool.com"/, 'contact fallback is available');

$html = render_book($empty);
like($html, qr/No errata reported/, 'empty state is displayed');
unlike($html, qr/<table\b/, 'empty state omits the table');

{
  local $ENV{PERLSCHOOL_ERRATA_FORM_URL} = 'https://formspree.io/f/testform';
  $app = PerlSchool::Build->new(schema => $schema, output_dir => $work->child('site'));
  $book->update({title => 'A "quoted" & useful book'});
  $html = render_book($book);
  like($html, qr/<form action="https:\/\/formspree.io\/f\/testform" method="post"/,
       'form retains an HTML POST fallback to the configured endpoint');
  like($html, qr/id="errataReportStatus" role="status" aria-live="polite"/,
       'submission feedback has a live region for assistive technology');
  like($html, qr/<script src="\/js\/errata\.js" defer><\/script>/,
       'configured form loads its AJAX submission script');
  like($html, qr/name="book_title" value="A &quot;quoted&quot; &amp; useful book"/, 'report identifies the escaped book title');
  like($html, qr/name="book_slug" value="data-munging"/, 'report identifies the book slug');
  like($html, qr/name="book_url" value="https:\/\/perlschool.com\/books\/data-munging\/"/, 'report includes the canonical book URL');
  like($html, qr/<input[^>]+name="name"[^>]+required>/, 'reporter name is required');
  like($html, qr/<textarea[^>]+name="description"[^>]+required>/, 'problem description is required');
  my ($email) = $html =~ /(<input[^>]+name="email"[^>]*>)/;
  like($email, qr/type="email"/, 'email uses browser email validation');
  unlike($email, qr/\brequired\b/, 'email is optional');

  $app->make_book_pages;
  for my $feature ($app->all_books) {
    my $page = $work->child('site/books', $feature->slug, 'index.html')->slurp_utf8;
    my @modals = $page =~ /id="errataModal"/g;
    is(scalar @modals, 1, $feature->slug . ': exactly one errata modal');
    like($page, qr/name="book_slug" value="\Q@{[$feature->slug]}\E"/,
         $feature->slug . ': report form identifies this book');
  }
  $app->make_index_page;
  unlike($work->child('site/index.html')->slurp_utf8, qr/id="errataModal"/,
         'home page has no book-specific errata modal');
}

{
  local $ENV{PERLSCHOOL_ERRATA_FORM_URL} = 'not-a-formspree-endpoint';
  my $bad = PerlSchool::Build->new;
  ok(!eval { $bad->errata_form_url; 1 }, 'invalid configured endpoint fails rather than publishing a broken form');
  like($@, qr/PERLSCHOOL_ERRATA_FORM_URL must be/, 'configuration error explains the setting');
}

done_testing;
