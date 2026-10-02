use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use File::Temp qw( tempdir );
use Path::Tiny qw( path );
use XML::Parser;

use PerlSchool::Build;

chdir "$FindBin::Bin/.." or die "Cannot enter repository root: $!";
my $output = path(tempdir(CLEANUP => 1));
my $app = PerlSchool::Build->new(
  output_dir => $output,
  schema => PerlSchool::Schema->get_schema('perlschool.db'),
);
{
  open my $build_log, '>', $output->child('build.log')
    or die "Cannot open build log: $!";
  local *STDOUT = $build_log;
  $app->run;
}

my $sitemap = $output->child('sitemap.xml');
like($sitemap->slurp_raw, qr/\A<\?xml /,
     'XML declaration starts at the first byte of the generated sitemap');

my ($root, $namespace, $in_location);
my @urls;
my $parser = XML::Parser->new(Handlers => {
  Start => sub {
    my ($parser, $element, %attributes) = @_;
    unless (defined $root) {
      $root = $element;
      $namespace = $attributes{xmlns};
    }
    if ($element eq 'loc') {
      push @urls, '';
      $in_location = 1;
    }
  },
  Char => sub { $urls[-1] .= $_[1] if $in_location },
  End => sub { $in_location = 0 if $_[1] eq 'loc' },
});
ok(eval { $parser->parsefile($sitemap->stringify); 1 },
   'sitemap from the full build parses directly as XML') or diag $@;
is($root, 'urlset', 'sitemap has the expected root element');
is($namespace, 'http://www.sitemaps.org/schemas/sitemap/0.9',
   'sitemap uses the expected namespace');
is_deeply(\@urls, $app->urls, 'sitemap contains every generated canonical URL');
ok(!grep({ /\/(?:our-instructor|dmp)\/$/ } @urls),
   'legacy redirect URLs are excluded from the sitemap');
my @missing_pages = grep {
  my $relative = substr($_, length($app->canonical_url));
  !$output->child($relative . 'index.html')->is_file;
} @urls;
is_deeply(\@missing_pages, [], 'each sitemap URL has a generated page');

done_testing;
