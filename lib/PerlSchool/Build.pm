package PerlSchool::Build;

use Moose;

use feature 'say';

use Template;
use Time::Piece;
use Path::Tiny;
use JSON;
use Carp;
use ENV::Util -load_dotenv;
use Amazon::Sites;

use PerlSchool::Schema;

has ['static_dir', 'output_dir'] => (
  isa        => 'Path::Tiny',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_static_dir {
  return path('static');
}

sub _build_output_dir {
  return path('docs');
}

has tt => (
  isa        => 'Template',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_tt {
  my $self = shift;

  my $tt = Template->new(
    INCLUDE_PATH => [qw(in ttlib)],
    OUTPUT_PATH  => $self->output_dir,
    WRAPPER      => 'page.tt',
    VARIABLES    => {
      buildyear  => localtime->year,
      app        => $self,
    },
  );

  warn "TT attribute: $tt\n";
  return $tt;
}

has json => (
  isa        => 'JSON',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_json {
  return JSON->new->utf8->pretty;
}

has schema => (
  isa        => 'PerlSchool::Schema',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_schema {
  my %config = ENV::Util::prefix2hash('PERLSCHOOL_');
  my $db = $config{db};
warn "$db\n";
  return PerlSchool::Schema->get_schema($db);
}

has canonical_url => (
  isa     => 'Str',
  is      => 'ro',
  default => 'https://perlschool.com/',
);

has urls => (
  isa     => 'ArrayRef',
  is      => 'rw',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    all_urls => 'elements',
    add_url  => 'push',
  },
);

has books => (
  isa        => 'ArrayRef',
  is         => 'rw',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_books => 'elements',
  },
);

sub _build_books {
  return [
    $_[0]->schema->books({
        is_perlschool_book => 1,
        is_live => 1,
      }, {
        order_by => { -desc => 'pubdate' },
      },
    )->all
  ];
}

has pages => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_pages => 'elements',
  },
);

has authors => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_authors => 'elements',
  },
);

sub _build_authors {
  return [
    $_[0]->schema->authors->perlschool_authors->sorted_authors
  ];
}

has amazon_sites => (
  isa        => 'Amazon::Sites',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_amazon_sites {
  my $self = shift;

  return Amazon::Sites->new(
    assoc_codes => $self->assoc_codes,
  );
}

has assoc_codes => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_assoc_codes {
  return {
    UK => 'davblog-21',
  };
}

has redirections => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_redirections {
  return {
    '/our-instructor/' => '/about',
    '/dmp/' => '/books/data-munging/',
  };
}

sub _build_pages {
  return [qw( books about contact write faq lpw )];
}

sub run {
  my $self = shift;

  $self->make_redirections;
  $self->make_static;
  $self->make_index_page;
  $self->make_book_pages;
  $self->make_authors_page;
  $self->make_other_pages;
  $self->make_sitemap;

  return;
}

sub make_static {
  my $self = shift;

  my $static = $self->static_dir->stringify;
  my $output = $self->output_dir->stringify;

  $self->static_dir->visit(
    sub {
      my ($source) = @_;
      return if $source->is_dir;
      my $target = path($source =~ s/$static/$output/re);
      say "$source -> $target [$static/$output]";

      $target->parent->mkdir unless $target->parent->exists;
      $source->copy($target);
    }, { recurse => 1 },
  )

  # $self->static_dir->copy($self->output_dir);
}

sub make_index_page {
  my $self = shift;

  my ($feature, @books) = $self->all_books;

  $self->make_page(
    'index.html.tt', {
      feature   => $feature,
      books     => \@books,
      canonical => $self->canonical_url,
    },
    'index.html',
  );

  return;
}

sub make_book_pages {
  my $self = shift;

  for my $feature ($self->all_books) {
    my $output = 'books/' . $feature->slug . '/index.html';
    $self->make_page(
      'book.html.tt', {
        feature   => $feature,
        books     => [ grep { $_->id != $feature->id } @{$self->books} ],
        canonical => $self->canonical_url . 'books/' . $feature->slug . '/',
        amazon_sites => $self->amazon_sites,
      },
      $output,
    );
  }

  return;
}

sub make_authors_page {
  my $self = shift;

  $self->make_page(
    'authors.html.tt', {
      authors   => $self->authors,
      books     => $self->books,
      canonical => $self->canonical_url . 'authors/',
    },
    'authors/index.html',
  );
}

sub make_other_pages {
  my $self = shift;

  for ( $self->all_pages ) {
    $self->make_page(
      "$_.html.tt", {
        books     => $self->books,
        canonical => $self->canonical_url . "$_/",
      },
      "$_/index.html",
    );
  }

  return;
}

sub make_redirections {
  my $self = shift;

  for my $from ( keys %{ $self->redirections } ) {
    my $to = $self->redirections->{$from};

    my $title = "Redirecting $from to $to";
    $self->make_page(
      'redirect.tt', {
        title => $title,
        redirect => $to,
      },
      "$from/index.html",
    );
  }
}

sub make_sitemap {
  my $self = shift;

  $self->make_page(
    'sitemap.xml.tt', {
      urls => $self->urls,
    },
    'sitemap.xml',
  );

  return;
}

sub make_page {
  my $self = shift;
  my ( $template, $vars, $output ) = @_;

  # Ensure the output directory exists
  my $output_path = path($self->output_dir, $output);
  $output_path->parent->mkpath;

  # Explicitly set the WRAPPER option
  my $options = {
    WRAPPER => 'page.tt',
  };

  $self->tt->process( $template, $vars, $output, $options )
    or croak $self->tt->error;

  if ( exists $vars->{canonical} ) {
    $self->add_url( $vars->{canonical} );
  }

  return;
}

sub authors_json {
  my $self = shift;

  my @authors = map { $_->json_ld_data } $self->all_authors;

  return $self->json->encode({
    '@context' => 'https://schema.org',
    '@type' => 'ItemList',
    itemListElement => \@authors
 });
}

1;
