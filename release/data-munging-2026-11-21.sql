-- Data Munging with Perl, second edition: the catalogue changes for publication
-- day (21 November 2026). Applied by .github/workflows/release-data-munging.yml.
--
-- It is safe to run more than once: the WHERE clause matches nothing once the
-- values are in place, so a second run changes nothing (and leaves the database
-- file byte-for-byte alone).
--
--   amazon_asin    the paperback's ASIN (Amazon button on the book page)
--   isbn           the paperback's ISBN-13
--   has_paperback  shows the "Paperback available" badge
--   highlights     the other badges, separated by colons: "WIP version" goes
--   buy_blurb      the text above the buy buttons: no longer the WIP notice
--
-- The "Coming soon" badge and the publication date need no change here: they
-- follow pubdate (2026-11-21) at the time the site is built.

UPDATE book
SET amazon_asin   = '1065495714',
    isbn          = '978-1065495710',
    has_paperback = 1,
    highlights    = 'Second edition:Updated for Perl 5.36 to 5.44',
    buy_blurb     = 'Available now as a paperback and a Kindle ebook from Amazon, and as a DRM-free PDF and EPUB from Leanpub. If you bought the work-in-progress edition from Leanpub, the final version is a free update.'
WHERE slug = 'data-munging'
  AND (   amazon_asin   IS NOT '1065495714'
       OR isbn          IS NOT '978-1065495710'
       OR has_paperback IS NOT 1
       OR highlights    IS NOT 'Second edition:Updated for Perl 5.36 to 5.44'
       OR buy_blurb     IS NOT 'Available now as a paperback and a Kindle ebook from Amazon, and as a DRM-free PDF and EPUB from Leanpub. If you bought the work-in-progress edition from Leanpub, the final version is a free update.');
