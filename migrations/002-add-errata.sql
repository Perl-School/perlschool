BEGIN TRANSACTION;

CREATE TABLE errata (
  id integer not null primary key,
  book_id integer not null references book(id),
  date_reported date not null default CURRENT_DATE,
  status text not null default 'Reported' CHECK (length(trim(status)) > 0),
  description text not null CHECK (length(trim(description)) > 0)
);

CREATE INDEX errata_book_id ON errata(book_id);

COMMIT;
