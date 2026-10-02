requires 'Amazon::Sites';
requires 'DBD::SQLite';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema::ResultSetNames';
requires 'DateTime';
requires 'DateTime::Format::SQLite';
requires 'ENV::Util';
requires 'HTML::Entities';
requires 'HTML::Strip';
requires 'JSON';
requires 'Moo';
requires 'Moose';
requires 'MooseX::NonMoose';
requires 'MooX::Role::JSON_LD';
requires 'Path::Tiny', '0.125';
requires 'Template';

on test => sub {
  requires 'XML::Parser';
};
