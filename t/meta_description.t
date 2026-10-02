use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use File::Copy qw( copy );
use File::Temp qw( tempdir );
use HTML::Entities qw( decode_entities );
use Path::Tiny qw( path );

use PerlSchool::Build;

sub description_for {
  my (%columns) = @_;
  return PerlSchool::Schema::Result::Book->new(\%columns)->meta_description;
}

my $blurb = '<p>Use <strong>&quot;Perl&quot; &amp; friends</strong></p>'
          . '<p>Second&nbsp;paragraph</p>';
my $plain_blurb = 'Use "Perl" & friends Second paragraph';

is(description_for(blurb => $blurb), $plain_blurb,
   'missing override falls back to stripped, decoded text with paragraph spacing');
is(description_for(blurb => $blurb, seo_description => ''), $plain_blurb,
   'empty override uses the blurb');
is(description_for(blurb => $blurb, seo_description => "\n\t\x{a0}"), $plain_blurb,
   'whitespace-only override uses the blurb');
is(description_for(blurb => '<p>Ignored</p>',
                   seo_description => "  A \"quoted\" summary & <literal> text.\n "),
   'A "quoted" summary & <literal> text.',
   'explicit plain-text summary takes precedence and is trimmed');
is(description_for(blurb => "  Plain\n\ttext  "), 'Plain text',
   'plain blurbs have whitespace normalized');
is(description_for(blurb => '<p>Today’s&nbsp;Perl &#x2014; café</p>'),
   'Today’s Perl — café', 'Unicode and numeric entities survive normalization');
is(description_for(blurb => '<p>&amp;lt;tag&amp;gt;</p>'), '&lt;tag&gt;',
   'entities are decoded once');
is(description_for(blurb => '<script>hidden</script><style>hidden</style><p>Visible</p>'),
   'Visible', 'script and style contents are excluded');
is(description_for(blurb => undef), '', 'absent blurb produces an empty description');

my $long_blurb = 'A useful sentence. ' x 30;
is(description_for(blurb => $long_blurb), $long_blurb =~ s/ $//r,
   'descriptions are not truncated');

my $row = PerlSchool::Schema::Result::Book->new({ blurb => $blurb });
$row->meta_description;
is($row->blurb, $blurb, 'deriving metadata preserves the rich blurb');

# Render the real book template against a disposable copy of the catalogue.
# This exercises ORM persistence and attribute escaping without changing source data.
chdir "$FindBin::Bin/.." or die "Cannot enter repository root: $!";
my $work_dir = path(tempdir(CLEANUP => 1));
my $database = $work_dir->child('catalogue.db');
copy('perlschool.db', $database->stringify) or die "Cannot copy catalogue: $!";
my $schema = PerlSchool::Schema->get_schema($database->stringify);
my $book = $schema->books->find({ slug => 'data-munging' });
die 'Data Munging fixture not found' unless $book;
my $app = PerlSchool::Build->new(
  schema => $schema,
  output_dir => $work_dir->child('site'),
);

for my $case (
  [ 'explicit summary', 'A "quoted" summary & <literal> text.',
    'A "quoted" summary & <literal> text.' ],
  [ 'HTML fallback', undef, $plain_blurb ],
) {
  my ($label, $override, $expected) = @$case;
  $book->update({ blurb => $blurb, seo_description => $override });
  $book->discard_changes;

  $app->make_page('book.html.tt', {
    feature => $book,
    books => [],
    canonical => 'https://perlschool.com/books/data-munging/',
  }, 'book/index.html');

  my $html = $work_dir->child('site/book/index.html')->slurp_utf8;
  for my $attribute (
    'name="description"',
    'property="og:description"',
    'name="twitter:description"',
  ) {
    my ($value) = $html =~ /<meta \Q$attribute\E content="([^"]*)">/;
    ok(defined $value, "$label: $attribute is a complete HTML attribute");
    is(decode_entities($value // ''), $expected,
       "$label: $attribute contains the expected plain text");
    like($value // '', qr/&quot;/, "$label: quotes are escaped");
    like($value // '', qr/&amp;/, "$label: ampersands are escaped");
    unlike($value // '', qr/[<>]/, "$label: angle brackets are escaped");
  }
  ok(index($html, $blurb) >= 0, "$label: book body retains the original rich HTML");
}

done_testing;
