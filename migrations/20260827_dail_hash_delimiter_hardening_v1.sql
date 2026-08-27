-- Prevent ambiguous inputs to the deployed DAIL v1.1.0 pipe-delimited hash.
--
-- The hash formula remains byte-for-byte unchanged for existing and future
-- compliant rows. The production readback before this migration found zero
-- pipe characters in every constrained field.

begin;

set local lock_timeout = '5s';

do $preflight$
declare
  v_missing_columns text[];
begin
  if pg_catalog.to_regclass('chlom_runtime.dail_events') is null then
    raise exception 'DAIL event table is absent; no changes applied'
      using errcode = '55000';
  end if;

  select pg_catalog.array_agg(required.column_name order by required.column_name)
    into v_missing_columns
  from (
    values
      ('schema_version'),
      ('event_type'),
      ('entity_type'),
      ('entity_id'),
      ('entity_version'),
      ('actor_did'),
      ('actor_ref')
  ) as required(column_name)
  where not exists (
    select 1
    from pg_catalog.pg_attribute a
    where a.attrelid = 'chlom_runtime.dail_events'::pg_catalog.regclass
      and a.attname = required.column_name
      and a.attnum > 0
      and not a.attisdropped
  );

  if v_missing_columns is not null then
    raise exception 'DAIL hash fields are absent: %', v_missing_columns
      using errcode = '55000';
  end if;
end
$preflight$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint c
    where c.conrelid = 'chlom_runtime.dail_events'::pg_catalog.regclass
      and c.conname = 'dail_events_hash_delimiter_v1_check'
  ) then
    alter table chlom_runtime.dail_events
      add constraint dail_events_hash_delimiter_v1_check
      check (
        pg_catalog.strpos(schema_version, '|') = 0
        and pg_catalog.strpos(event_type, '|') = 0
        and pg_catalog.strpos(entity_type, '|') = 0
        and pg_catalog.strpos(entity_id, '|') = 0
        and pg_catalog.strpos(coalesce(entity_version, ''), '|') = 0
        and pg_catalog.strpos(coalesce(actor_did, ''), '|') = 0
        and pg_catalog.strpos(coalesce(actor_ref, ''), '|') = 0
      ) not valid;
  end if;
end
$constraint$;

alter table chlom_runtime.dail_events
  validate constraint dail_events_hash_delimiter_v1_check;

commit;
