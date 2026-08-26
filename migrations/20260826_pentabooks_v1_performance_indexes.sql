-- PentaBooks v1 performance indexes. Applied to ThriveBase on 2026-08-26.
create index if not exists penta_book_assets_edition_idx on public.penta_book_assets(edition_id);
create index if not exists penta_canon_facts_supersedes_idx on public.penta_canon_facts(supersedes);
create index if not exists penta_book_qa_runs_standard_idx on public.penta_book_qa_runs(standard_id);
