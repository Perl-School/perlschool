use utf8;
package PerlSchool::Schema::Result::Book;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PerlSchool::Schema::Result::Book

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<book>

=cut

__PACKAGE__->table("book");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 title

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 subtitle

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 slug

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 pubdate

  data_type: 'date'
  is_nullable: 0

=head2 blurb

  data_type: 'varchar'
  is_nullable: 0
  size: 1000

=head2 image

  data_type: 'varchar'
  is_nullable: 0
  size: 200

=head2 amazon_asin

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 leanpub_slug

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 examples

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 author_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 is_perlschool_book

  data_type: 'boolean'
  default_value: 1
  is_nullable: 0

=head2 is_live

  data_type: 'boolean'
  default_value: 1
  is_nullable: 0

=head2 upddate

  data_type: 'date'
  is_nullable: 1

=head2 toc

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 highlights

  data_type: 'text'
  is_nullable: 1

=head2 has_paperback

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 isbn

  data_type: 'char'
  is_nullable: 1
  size: 15

=head2 website

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "subtitle",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "slug",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "pubdate",
  { data_type => "date", is_nullable => 0 },
  "blurb",
  { data_type => "varchar", is_nullable => 0, size => 1000 },
  "image",
  { data_type => "varchar", is_nullable => 0, size => 200 },
  "amazon_asin",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "leanpub_slug",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "examples",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "author_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_perlschool_book",
  { data_type => "boolean", default_value => 1, is_nullable => 0 },
  "is_live",
  { data_type => "boolean", default_value => 1, is_nullable => 0 },
  "upddate",
  { data_type => "date", is_nullable => 1 },
  "toc",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "highlights",
  { data_type => "text", is_nullable => 1 },
  "has_paperback",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "isbn",
  { data_type => "char", is_nullable => 1, size => 15 },
  "website",
  { data_type => "varchar", is_nullable => 1, size => 100 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 amazon_sales

Type: has_many

Related object: L<PerlSchool::Schema::Result::AmazonSale>

=cut

__PACKAGE__->has_many(
  "amazon_sales",
  "PerlSchool::Schema::Result::AmazonSale",
  { "foreign.book_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 author

Type: belongs_to

Related object: L<PerlSchool::Schema::Result::Author>

=cut

__PACKAGE__->belongs_to(
  "author",
  "PerlSchool::Schema::Result::Author",
  { id => "author_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-09-01 15:27:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k7pSuk5ZwCIijcowmxmAIQ

use Moo;
with 'MooX::Role::JSON_LD';

use DateTime;

sub json_ld_type { 'Book' };

sub json_ld_fields { [
  { name => sub {
    $_[0]->subtitle ? $_[0]->title . ' - ' . $_[0]->subtitle : $_[0]->title}
  },
  { bookFormat => sub { 'EBook' } },
  { author => sub { {
    name => $_[0]->author->name,
    '@type' => 'Person',
  } } },
  { image => sub {
      'https://perlschool.com/images/' . $_[0]->image . '.webp'
    }
  },
  { datePublished => sub { $_[0]->pubdate->strftime('%Y-%m-%d') }},
  { publisher => sub { {
    name => 'Perl School Publishing',
    '@type' => 'Organization',
  } } },
]}

sub has_extras {
  my $self = shift;

  for (qw( examples toc description )) {
    return 1 if $self->$_;
  }

  return;
}

sub is_published {
  my $self = shift;

  return $self->pubdate <= DateTime->now;
}

sub highlight_list {
  my $self = shift;

  return unless $self->highlights;

  return [ split /:/, $self->highlights ];
}

sub has_badges {
  my $self = shift;

  return $self->has_paperback || $self->highlights || ! $self->is_published;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
