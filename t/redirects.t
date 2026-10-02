use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use File::Temp qw( tempdir );
use HTML::Entities qw( decode_entities );
use Path::Tiny qw( path );

use PerlSchool::Build;

chdir "$FindBin::Bin/.." or die "Cannot enter repository root: $!";
my $output = path(tempdir(CLEANUP => 1));
my $app = PerlSchool::Build->new(output_dir => $output);
$app->make_redirections;

for my $route (
  [ 'our-instructor', '/about' ],
  [ 'dmp', '/books/data-munging/' ],
) {
  my ($slug, $target) = @$route;
  my $file = $output->child("$slug/index.html");
  ok($file->is_file, "$slug: legacy route is generated");
  my $html = $file->slurp_utf8;
  like($html, qr/<!DOCTYPE html>\s*<html\b.*<\/html>/s,
       "$slug: redirect is a complete HTML document");

  my ($head) = $html =~ /<head>(.*?)<\/head>/s;
  like($head // '', qr/<meta http-equiv="refresh" content="0; URL=\Q$target\E">/,
       "$slug: immediate redirect in the head points to the intended route");
  like($head // '', qr/<link rel="canonical" href="\Q$target\E">/,
       "$slug: canonical link points to the destination");
  like($html, qr/<body>.*<a href="\Q$target\E">\Q$target\E<\/a>.*<\/body>/s,
       "$slug: visible fallback link points to the destination");
}

my $target = '/target/?first=1&second="quoted"';
my $escaped_app = PerlSchool::Build->new(
  output_dir => $output,
  redirections => { '/escaped/' => $target },
);
$escaped_app->make_redirections;
my $html = $output->child('escaped/index.html')->slurp_utf8;
my ($refresh) = $html =~ /<meta http-equiv="refresh" content="([^"]*)">/;
is(decode_entities($refresh // ''), "0; URL=$target",
   'redirect target preserves ampersands and quotes in a complete attribute');
my ($link) = $html =~ /<a href="([^"]*)">/;
is(decode_entities($link // ''), $target, 'fallback URL is escaped without changing its value');
my ($title) = $html =~ /<title>(.*?)<\/title>/s;
is(decode_entities($title // ''), "Redirecting /escaped/ to $target",
   'redirect title is escaped and preserved by the wrapper');

done_testing;
