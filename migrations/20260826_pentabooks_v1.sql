-- PentaBooks v1 production schema. Applied to ThriveBase on 2026-08-26.
-- Source policy: Virality Music public production site -> approved Work artifacts -> project sources -> project chats.

create table if not exists public.penta_book_system_state (
  system_key text primary key, name text not null, version text not null,
  status text not null, canonical_source_policy jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz not null default now(), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.penta_books (
  id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null,
  universe text, series text, book_number integer, creator text not null default 'Kavonte Jones Sr.',
  imprint text not null default 'Virality Music by CrownThrive', owner text not null default 'CrownThrive LLC',
  canonical_status text not null default 'governed', maturity text not null default 'active', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.penta_book_editions (
  id uuid primary key default gen_random_uuid(), book_id uuid not null references public.penta_books(id) on delete restrict,
  version text not null, edition_name text not null, format text not null default 'pdf', status text not null default 'draft',
  vm_standard text not null default 'VM-BOOK-001', source_uri text, sha256 text, page_count integer, word_count integer, illustration_count integer,
  rights_status text not null default 'review_required', accessibility_status text not null default 'review_required', release_status text not null default 'not_ready',
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(book_id,version,edition_name,format)
);
create table if not exists public.penta_book_assets (
  id uuid primary key default gen_random_uuid(), edition_id uuid not null references public.penta_book_editions(id) on delete cascade,
  role text not null, uri text not null, sha256 text, mime_type text, rights_status text not null default 'review_required',
  accessibility_status text not null default 'review_required', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), unique(edition_id,role,uri)
);
create table if not exists public.penta_book_sources (
  id uuid primary key default gen_random_uuid(), source_key text not null unique, source_type text not null, priority integer not null default 50,
  uri text, trust_scope text, is_canonical boolean not null default true, state text not null default 'active', last_checked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.penta_canon_facts (
  id uuid primary key default gen_random_uuid(), book_id uuid references public.penta_books(id) on delete restrict, namespace text not null default 'global',
  fact_key text not null, fact_value jsonb not null, status text not null default 'fixed', source_type text not null, source_ref text not null,
  source_locator text, source_rank integer not null default 50, supersedes uuid references public.penta_canon_facts(id) on delete restrict,
  effective_from timestamptz not null default now(), recorded_at timestamptz not null default now()
);
create table if not exists public.penta_book_standards (
  standard_id text primary key, name text not null, version text not null, mandatory_gates jsonb not null default '[]'::jsonb,
  rules jsonb not null default '{}'::jsonb, source_ref text not null, effective_date date not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.penta_book_qa_runs (
  id uuid primary key default gen_random_uuid(), edition_id uuid not null references public.penta_book_editions(id) on delete cascade,
  standard_id text not null references public.penta_book_standards(standard_id) on delete restrict, gate_id text not null,
  status text not null, score numeric(6,2), findings jsonb not null default '{}'::jsonb, evidence_uri text,
  run_at timestamptz not null default now(), signed_off_by text, signed_off_at timestamptz
);
create table if not exists public.penta_book_bindings (
  binding_id text primary key, target text not null, mode text not null, authority text not null, capabilities jsonb not null default '{}'::jsonb,
  endpoint text, state text not null default 'registered', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.penta_book_events (
  id bigint generated always as identity primary key, event_type text not null, aggregate_type text not null, aggregate_id text not null,
  payload jsonb not null default '{}'::jsonb, delivery_state text not null default 'pending', created_at timestamptz not null default now(), delivered_at timestamptz
);

create index if not exists penta_books_universe_idx on public.penta_books(universe,series,book_number);
create index if not exists penta_book_editions_book_idx on public.penta_book_editions(book_id,updated_at desc);
create index if not exists penta_book_sources_priority_idx on public.penta_book_sources(priority,source_key);
create index if not exists penta_canon_fact_lookup_idx on public.penta_canon_facts(book_id,namespace,fact_key,recorded_at desc);
create index if not exists penta_qa_latest_idx on public.penta_book_qa_runs(edition_id,gate_id,run_at desc);
create index if not exists penta_book_events_outbox_idx on public.penta_book_events(delivery_state,created_at);

alter table public.penta_book_system_state enable row level security;
alter table public.penta_books enable row level security;
alter table public.penta_book_editions enable row level security;
alter table public.penta_book_assets enable row level security;
alter table public.penta_book_sources enable row level security;
alter table public.penta_canon_facts enable row level security;
alter table public.penta_book_standards enable row level security;
alter table public.penta_book_qa_runs enable row level security;
alter table public.penta_book_bindings enable row level security;
alter table public.penta_book_events enable row level security;

-- Client roles are explicitly denied. Edge Functions use the service role and therefore remain the bounded production control path.
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='penta_books' and policyname='pentabooks_books_internal_only') then create policy "pentabooks_books_internal_only" on public.penta_books for all to authenticated using(false) with check(false); end if;
end $$;

revoke all on public.penta_book_system_state,public.penta_books,public.penta_book_editions,public.penta_book_assets,public.penta_book_sources,public.penta_canon_facts,public.penta_book_standards,public.penta_book_qa_runs,public.penta_book_bindings,public.penta_book_events from anon,authenticated;

insert into public.penta_book_system_state(system_key,name,version,status,canonical_source_policy,last_verified_at,updated_at)
values('pentabooks','PentaBooks','1.0.0','operational',
'{"governing_sources":["https://virality-music.crownthrive.chatgpt.site","ChatGPT Work production artifacts","PentaBooks project sources","PentaBooks project chats"],"conflict_rule":"newer explicit project directive governs; preserve prior versions rather than silently overwriting","canon_rule":"fixed/open/sealed/disputed facts remain explicitly classified"}'::jsonb,now(),now())
on conflict(system_key) do update set name=excluded.name,version=excluded.version,status=excluded.status,canonical_source_policy=excluded.canonical_source_policy,last_verified_at=now(),updated_at=now();

insert into public.penta_book_standards(standard_id,name,version,mandatory_gates,rules,source_ref,effective_date,updated_at) values
('VM-BOOK-001','Virality Music Publication Standard and Release Workflow','1.0.0','["canon","narrative_depth","accountability","unique_art","packaging","navigation","page_by_page_qa","pricing","correction_notice","release_signoff"]'::jsonb,'{"prior_version_preserved":true,"searchable_text_required":true,"linked_contents_required":true,"bookmarks_required":true,"release_requires_all_mandatory_gates":true}'::jsonb,'PentaBooks project source: Lenora final release details / VM-BOOK-001','2026-07-28',now()),
('VM-BOOK-002','Virality Music Premium Publishing, Fine-Press Collector Edition, and $200+ Book Production Canon','1.0.0','["vm_book_001_pass","collector_material_spec","declared_scarcity","edition_numbering","physical_manufacturing_qa","provenance","collector_fulfillment","standalone_pricing","rights_and_adaptation","release_signoff"]'::jsonb,'{"extends":"VM-BOOK-001","bundles_prohibited":true,"ordinary_ebook_over_200_prohibited":true,"numbered_physical_archive_edition_required_for_200_plus":true}'::jsonb,'PentaBooks project source: VM-BOOK-002 directive','2026-07-28',now())
on conflict(standard_id) do update set name=excluded.name,version=excluded.version,mandatory_gates=excluded.mandatory_gates,rules=excluded.rules,source_ref=excluded.source_ref,effective_date=excluded.effective_date,updated_at=now();
