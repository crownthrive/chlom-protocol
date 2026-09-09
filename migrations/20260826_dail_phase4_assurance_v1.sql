-- CHLOM DAIL Phase-4 assurance support v1.
--
-- Scope:
--   * preserve the existing chlom_runtime.dail_events ledger and its functions;
--   * record verified, provider-independent cold-checkpoint custody receipts;
--   * record append-only isolated recovery-drill receipts; and
--   * expose a bounded, service-role-only hot/cold assurance readback.
--
-- This migration is additive. It does not activate institutional Phase 4, create a
-- public data route, or claim that a metadata-only drill is a full data restore.
-- Canonical source custody: crownthrive1/chlom-protocol, this exact migration file.
-- The preflight makes a direct apply fail atomically if the live, source-drifted
-- database no longer has the bounded prerequisites this migration was built for.

begin;

do $preflight$
declare
  v_append regprocedure := pg_catalog.to_regprocedure(
    'chlom_runtime.append_dail_event(text,text,text,jsonb,text,text,text,text,text,text,text,text,text)'
  );
begin
  if pg_catalog.to_regclass('chlom_runtime.dail_events') is null
     or pg_catalog.to_regprocedure('chlom_runtime.verify_dail_chain()') is null
     or v_append is null then
    raise exception 'DAIL assurance v1 prerequisites are absent; no changes applied'
      using errcode = '55000';
  end if;
  if pg_catalog.strpos(
       pg_catalog.pg_get_functiondef(v_append),
       'chlom_runtime.dail.global.v1'
     ) = 0 then
    raise exception 'DAIL append lock contract drifted; no changes applied'
      using errcode = '55000';
  end if;
  if pg_catalog.to_regprocedure('extensions.digest(bytea,text)') is null
     or pg_catalog.to_regprocedure('extensions.gen_random_uuid()') is null then
    raise exception 'required pgcrypto functions are absent; no changes applied'
      using errcode = '55000';
  end if;
  if pg_catalog.to_regprocedure('public.chlom_mesh_public_status_v1()') is null then
    raise exception 'CHLOM mesh public status prerequisite is absent; no changes applied'
      using errcode = '55000';
  end if;
end
$preflight$;

create table if not exists chlom_runtime.dail_cold_checkpoints_v1 (
  checkpoint_id uuid primary key default extensions.gen_random_uuid(),
  idempotency_key text not null unique,

  source_event_count bigint not null,
  source_min_sequence_id bigint not null,
  source_max_sequence_id bigint not null,
  source_head_event_hash text not null,
  source_head_created_at timestamptz not null,
  snapshot_created_at timestamptz not null,
  snapshot_rpo_seconds bigint not null,

  hot_event_count_at_recording bigint not null,
  hot_max_sequence_id_at_recording bigint not null,
  hot_head_event_hash_at_recording text not null,
  hot_integrity_state text not null,
  verification_checked_at timestamptz not null,
  verification_failure_count integer not null,
  documented_correction_count integer not null,
  verifier_output jsonb not null,
  verifier_output_sha256 text not null,

  snapshot_manifest_sha256 text not null,
  snapshot_package_sha256 text not null,
  snapshot_object_ref text not null,
  snapshot_bytes bigint not null,
  storage_provider text not null,
  encryption_state text not null,
  custody_verified boolean not null,
  readback_verified boolean not null,
  restore_path_verified boolean not null,

  receipt_dail_event_id uuid,
  recorded_by text not null,
  authority_basis text not null,
  recorded_at timestamptz not null default pg_catalog.clock_timestamp(),
  previous_checkpoint_receipt_sha256 text,
  checkpoint_receipt_sha256 text not null unique,

  constraint dail_cold_checkpoint_idempotency_key_v1_check
    check (pg_catalog.length(pg_catalog.btrim(idempotency_key)) between 8 and 200),
  constraint dail_cold_checkpoint_source_range_v1_check
    check (
      source_event_count > 0
      and source_min_sequence_id > 0
      and source_max_sequence_id >= source_min_sequence_id
      and source_event_count <= source_max_sequence_id
      and hot_event_count_at_recording >= source_event_count
      and hot_max_sequence_id_at_recording >= source_max_sequence_id
    ),
  constraint dail_cold_checkpoint_source_head_hash_v1_check
    check (source_head_event_hash ~ '^[0-9a-f]{64}$'),
  constraint dail_cold_checkpoint_hot_head_hash_v1_check
    check (hot_head_event_hash_at_recording ~ '^[0-9a-f]{64}$'),
  constraint dail_cold_checkpoint_snapshot_manifest_hash_v1_check
    check (snapshot_manifest_sha256 ~ '^[0-9a-f]{64}$'),
  constraint dail_cold_checkpoint_snapshot_package_hash_v1_check
    check (snapshot_package_sha256 ~ '^[0-9a-f]{64}$'),
  constraint dail_cold_checkpoint_verifier_hash_v1_check
    check (verifier_output_sha256 ~ '^[0-9a-f]{64}$'),
  constraint dail_cold_checkpoint_receipt_linkage_v1_check
    check (
      (previous_checkpoint_receipt_sha256 is null
        or previous_checkpoint_receipt_sha256 ~ '^[0-9a-f]{64}$')
      and checkpoint_receipt_sha256 ~ '^[0-9a-f]{64}$'
    ),
  constraint dail_cold_checkpoint_previous_receipt_v1_fkey
    foreign key (previous_checkpoint_receipt_sha256)
      references chlom_runtime.dail_cold_checkpoints_v1(checkpoint_receipt_sha256)
      on delete restrict,
  constraint dail_cold_checkpoint_time_order_v1_check
    check (snapshot_created_at >= source_head_created_at),
  constraint dail_cold_checkpoint_rpo_v1_check
    check (snapshot_rpo_seconds >= 0),
  constraint dail_cold_checkpoint_hot_integrity_v1_check
    check (
      hot_integrity_state in ('pass', 'pass_with_documented_legacy_correction')
      and verification_failure_count = 0
      and documented_correction_count >= 0
    ),
  constraint dail_cold_checkpoint_snapshot_bytes_v1_check
    check (snapshot_bytes > 0),
  constraint dail_cold_checkpoint_storage_provider_v1_check
    check (
      storage_provider in (
        'google_drive',
        's3',
        'gcs',
        'azure_blob',
        'other_provider_managed'
      )
    ),
  constraint dail_cold_checkpoint_encryption_v1_check
    check (
      encryption_state in (
        'provider_managed_at_rest',
        'client_managed',
        'provider_and_client_managed'
      )
    ),
  constraint dail_cold_checkpoint_certified_readback_v1_check
    check (custody_verified and readback_verified and restore_path_verified),
  constraint dail_cold_checkpoint_object_ref_v1_check
    check (pg_catalog.length(pg_catalog.btrim(snapshot_object_ref)) between 1 and 1024),
  constraint dail_cold_checkpoint_actor_v1_check
    check (
      pg_catalog.length(pg_catalog.btrim(recorded_by)) between 1 and 255
      and pg_catalog.length(pg_catalog.btrim(authority_basis)) between 1 and 1024
    )
);

create index if not exists dail_cold_checkpoints_recorded_at_v1_idx
  on chlom_runtime.dail_cold_checkpoints_v1 (recorded_at desc);

create index if not exists dail_cold_checkpoints_source_head_v1_idx
  on chlom_runtime.dail_cold_checkpoints_v1 (source_head_event_hash);

create table if not exists chlom_runtime.dail_recovery_drill_receipts_v1 (
  drill_id uuid primary key default extensions.gen_random_uuid(),
  idempotency_key text not null unique,
  checkpoint_id uuid not null
    references chlom_runtime.dail_cold_checkpoints_v1(checkpoint_id) on delete restrict,

  test_scope text not null,
  restore_target_class text not null,
  restore_environment_ref text not null,
  drill_started_at timestamptz not null,
  drill_completed_at timestamptz not null,
  observed_rpo_seconds bigint not null,
  observed_rto_seconds bigint not null,

  restored_event_count bigint,
  restored_max_sequence_id bigint,
  restored_head_event_hash text,
  source_head_match boolean not null,
  manifest_hash_verified boolean not null,
  package_hash_verified boolean not null,
  component_hashes_verified boolean not null,
  structured_data_parse_verified boolean not null,
  restore_path_verified boolean not null,
  cold_route_exercised boolean not null,
  hot_route_unchanged boolean not null,
  fault_injection_verified boolean not null,
  provider_exit_path_verified boolean not null,
  rollback_and_failback_verified boolean not null,
  result text not null,

  receipt_dail_event_id uuid,
  recorded_by text not null,
  authority_basis text not null,
  recorded_at timestamptz not null default pg_catalog.clock_timestamp(),

  constraint dail_recovery_drill_idempotency_key_v1_check
    check (pg_catalog.length(pg_catalog.btrim(idempotency_key)) between 8 and 200),
  constraint dail_recovery_drill_scope_v1_check
    check (test_scope in ('metadata_manifest', 'ledger_lineage', 'full_data_restore')),
  constraint dail_recovery_drill_nonproduction_v1_check
    check (restore_target_class = 'isolated_non_production'),
  constraint dail_recovery_drill_environment_ref_v1_check
    check (pg_catalog.length(pg_catalog.btrim(restore_environment_ref)) between 1 and 1024),
  constraint dail_recovery_drill_time_order_v1_check
    check (drill_completed_at >= drill_started_at),
  constraint dail_recovery_drill_objectives_v1_check
    check (observed_rpo_seconds >= 0 and observed_rto_seconds >= 0),
  constraint dail_recovery_drill_restored_values_v1_check
    check (
      (restored_event_count is null or restored_event_count >= 0)
      and (restored_max_sequence_id is null or restored_max_sequence_id >= 0)
      and (
        restored_head_event_hash is null
        or restored_head_event_hash ~ '^[0-9a-f]{64}$'
      )
    ),
  constraint dail_recovery_drill_result_v1_check
    check (
      result in ('PASS', 'FAIL')
      and (
        (result = 'PASS') = (
          source_head_match
          and manifest_hash_verified
          and package_hash_verified
          and component_hashes_verified
          and structured_data_parse_verified
          and restore_path_verified
          and cold_route_exercised
          and hot_route_unchanged
          and fault_injection_verified
          and provider_exit_path_verified
          and rollback_and_failback_verified
        )
      )
    ),
  constraint dail_recovery_drill_actor_v1_check
    check (
      pg_catalog.length(pg_catalog.btrim(recorded_by)) between 1 and 255
      and pg_catalog.length(pg_catalog.btrim(authority_basis)) between 1 and 1024
    )
);

create index if not exists dail_recovery_drill_completed_at_v1_idx
  on chlom_runtime.dail_recovery_drill_receipts_v1 (drill_completed_at desc);

create index if not exists dail_recovery_drill_checkpoint_v1_idx
  on chlom_runtime.dail_recovery_drill_receipts_v1 (checkpoint_id, drill_completed_at desc);

alter table chlom_runtime.dail_cold_checkpoints_v1 enable row level security;
alter table chlom_runtime.dail_cold_checkpoints_v1 force row level security;
alter table chlom_runtime.dail_recovery_drill_receipts_v1 enable row level security;
alter table chlom_runtime.dail_recovery_drill_receipts_v1 force row level security;

-- No table policies are intentional. Direct table access fails closed; the bounded
-- SECURITY DEFINER functions below are the only service-role data path.
revoke all on table chlom_runtime.dail_cold_checkpoints_v1
  from public, anon, authenticated, service_role;
revoke all on table chlom_runtime.dail_recovery_drill_receipts_v1
  from public, anon, authenticated, service_role;

create or replace function chlom_runtime.reject_dail_assurance_mutation_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception 'DAIL assurance receipts are append-only'
    using errcode = '55000';
  return null;
end
$function$;

do $block$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'chlom_runtime'
      and c.relname = 'dail_cold_checkpoints_v1'
      and t.tgname = 'dail_cold_checkpoints_append_only_v1'
      and not t.tgisinternal
  ) then
    create trigger dail_cold_checkpoints_append_only_v1
      before update or delete on chlom_runtime.dail_cold_checkpoints_v1
      for each row execute function chlom_runtime.reject_dail_assurance_mutation_v1();
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'chlom_runtime'
      and c.relname = 'dail_cold_checkpoints_v1'
      and t.tgname = 'dail_cold_checkpoints_reject_truncate_v1'
      and not t.tgisinternal
  ) then
    create trigger dail_cold_checkpoints_reject_truncate_v1
      before truncate on chlom_runtime.dail_cold_checkpoints_v1
      for each statement execute function chlom_runtime.reject_dail_assurance_mutation_v1();
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'chlom_runtime'
      and c.relname = 'dail_recovery_drill_receipts_v1'
      and t.tgname = 'dail_recovery_drill_receipts_append_only_v1'
      and not t.tgisinternal
  ) then
    create trigger dail_recovery_drill_receipts_append_only_v1
      before update or delete on chlom_runtime.dail_recovery_drill_receipts_v1
      for each row execute function chlom_runtime.reject_dail_assurance_mutation_v1();
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'chlom_runtime'
      and c.relname = 'dail_recovery_drill_receipts_v1'
      and t.tgname = 'dail_recovery_drill_receipts_reject_truncate_v1'
      and not t.tgisinternal
  ) then
    create trigger dail_recovery_drill_receipts_reject_truncate_v1
      before truncate on chlom_runtime.dail_recovery_drill_receipts_v1
      for each statement execute function chlom_runtime.reject_dail_assurance_mutation_v1();
  end if;
end
$block$;

create or replace function chlom_runtime.record_dail_cold_checkpoint_v1(
  p_idempotency_key text,
  p_source_event_count bigint,
  p_source_max_sequence_id bigint,
  p_source_head_event_hash text,
  p_snapshot_created_at timestamptz,
  p_snapshot_manifest_sha256 text,
  p_snapshot_package_sha256 text,
  p_snapshot_object_ref text,
  p_snapshot_bytes bigint,
  p_storage_provider text,
  p_encryption_state text,
  p_custody_verified boolean,
  p_readback_verified boolean,
  p_restore_path_verified boolean,
  p_recorded_by text,
  p_authority_basis text,
  p_receipt_dail_event_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set "TimeZone" = 'UTC'
as $function$
declare
  v_idempotency_key text := pg_catalog.btrim(p_idempotency_key);
  v_source_head_hash text := pg_catalog.lower(pg_catalog.btrim(p_source_head_event_hash));
  v_manifest_hash text := pg_catalog.lower(pg_catalog.btrim(p_snapshot_manifest_sha256));
  v_package_hash text := pg_catalog.lower(pg_catalog.btrim(p_snapshot_package_sha256));
  v_snapshot_object_ref text := pg_catalog.btrim(p_snapshot_object_ref);
  v_recorded_by text := pg_catalog.btrim(p_recorded_by);
  v_authority_basis text := pg_catalog.btrim(p_authority_basis);
  v_verification jsonb;
  v_source_min_sequence_id bigint;
  v_source_actual_event_count bigint;
  v_source_head_created_at timestamptz;
  v_hot_event_count bigint;
  v_hot_max_sequence_id bigint;
  v_hot_head_event_hash text;
  v_snapshot_rpo_seconds bigint;
  v_checkpoint_id uuid;
  v_candidate_checkpoint_id uuid := extensions.gen_random_uuid();
  v_recorded_at timestamptz := pg_catalog.clock_timestamp();
  v_verifier_output_sha256 text;
  v_previous_checkpoint_receipt_sha256 text;
  v_checkpoint_receipt_sha256 text;
  v_existing chlom_runtime.dail_cold_checkpoints_v1%rowtype;
begin
  if v_idempotency_key is null
     or pg_catalog.length(v_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_source_event_count is null or p_source_event_count <= 0
     or p_source_max_sequence_id is null or p_source_max_sequence_id <= 0 then
    raise exception 'source event count and max sequence must be positive'
      using errcode = '22023';
  end if;
  if v_source_head_hash is null or v_source_head_hash !~ '^[0-9a-f]{64}$'
     or v_manifest_hash is null or v_manifest_hash !~ '^[0-9a-f]{64}$'
     or v_package_hash is null or v_package_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'source, manifest, and package hashes must be lowercase SHA-256 values'
      using errcode = '22023';
  end if;
  if p_snapshot_created_at is null
     or p_snapshot_created_at > pg_catalog.clock_timestamp() + interval '5 minutes' then
    raise exception 'snapshot creation time is invalid' using errcode = '22023';
  end if;
  if p_snapshot_bytes is null or p_snapshot_bytes <= 0 then
    raise exception 'snapshot byte count must be positive' using errcode = '22023';
  end if;
  if p_storage_provider is null or p_storage_provider not in (
       'google_drive', 's3', 'gcs', 'azure_blob', 'other_provider_managed'
     ) then
    raise exception 'unsupported storage provider' using errcode = '22023';
  end if;
  if p_encryption_state is null or p_encryption_state not in (
       'provider_managed_at_rest', 'client_managed', 'provider_and_client_managed'
     ) then
    raise exception 'unsupported encryption state' using errcode = '22023';
  end if;
  if p_custody_verified is distinct from true
     or p_readback_verified is distinct from true
     or p_restore_path_verified is distinct from true then
    raise exception 'cold checkpoint requires custody, readback, and restore-path verification'
      using errcode = '22023';
  end if;
  if v_snapshot_object_ref is null
     or pg_catalog.length(v_snapshot_object_ref) not between 1 and 1024
     or v_recorded_by is null
     or pg_catalog.length(v_recorded_by) not between 1 and 255
     or v_authority_basis is null
     or pg_catalog.length(v_authority_basis) not between 1 and 1024 then
    raise exception 'object reference, recorder, or authority basis is invalid'
      using errcode = '22023';
  end if;

  -- Share the ledger's global append lock so prefix checks cannot race an append.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('chlom_runtime.dail.global.v1')
  );

  v_verification := chlom_runtime.verify_dail_chain();
  if coalesce((v_verification ->> 'ok')::boolean, false) is distinct from true
     or coalesce((v_verification ->> 'failure_count')::integer, -1) <> 0 then
    raise exception 'hot DAIL integrity verification did not pass'
      using errcode = '55000';
  end if;

  select e.created_at
    into v_source_head_created_at
  from chlom_runtime.dail_events e
  where e.sequence_id = p_source_max_sequence_id
    and e.event_hash = v_source_head_hash;

  if not found then
    raise exception 'snapshot source head is not present in the immutable DAIL chain'
      using errcode = '22023';
  end if;

  select pg_catalog.count(*), pg_catalog.min(e.sequence_id)
    into v_source_actual_event_count, v_source_min_sequence_id
  from chlom_runtime.dail_events e
  where e.sequence_id <= p_source_max_sequence_id;

  if v_source_actual_event_count <> p_source_event_count then
    raise exception 'snapshot event count does not match its DAIL source prefix'
      using errcode = '22023';
  end if;

  select pg_catalog.count(*), pg_catalog.max(e.sequence_id)
    into v_hot_event_count, v_hot_max_sequence_id
  from chlom_runtime.dail_events e;

  select e.event_hash
    into v_hot_head_event_hash
  from chlom_runtime.dail_events e
  order by e.sequence_id desc
  limit 1;

  if coalesce((v_verification ->> 'checked_events')::bigint, -1) <> v_hot_event_count
     or v_verification ->> 'head_hash' is distinct from v_hot_head_event_hash then
    raise exception 'hot DAIL readback is internally inconsistent'
      using errcode = '55000';
  end if;
  if p_snapshot_created_at < v_source_head_created_at then
    raise exception 'snapshot predates its declared source head'
      using errcode = '22023';
  end if;

  v_snapshot_rpo_seconds := pg_catalog.ceil(
    extract(epoch from p_snapshot_created_at - v_source_head_created_at)
  )::bigint;

  v_verifier_output_sha256 := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_verification::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  select c.checkpoint_receipt_sha256
    into v_previous_checkpoint_receipt_sha256
  from chlom_runtime.dail_cold_checkpoints_v1 c
  order by c.recorded_at desc, c.checkpoint_id desc
  limit 1;

  -- This chain is independent of the DAIL event chain. It binds each custody
  -- receipt to the verifier output, source prefix, package, and prior receipt.
  v_checkpoint_receipt_sha256 := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'previous_checkpoint_receipt_sha256',
            coalesce(v_previous_checkpoint_receipt_sha256, 'GENESIS'),
          'checkpoint_id', v_candidate_checkpoint_id,
          'idempotency_key', v_idempotency_key,
          'source_event_count', p_source_event_count,
          'source_max_sequence_id', p_source_max_sequence_id,
          'source_head_event_hash', v_source_head_hash,
          'snapshot_created_at', pg_catalog.to_char(
            p_snapshot_created_at at time zone 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          ),
          'snapshot_manifest_sha256', v_manifest_hash,
          'snapshot_package_sha256', v_package_hash,
          'snapshot_object_ref', v_snapshot_object_ref,
          'snapshot_bytes', p_snapshot_bytes,
          'storage_provider', p_storage_provider,
          'encryption_state', p_encryption_state,
          'verifier_output_sha256', v_verifier_output_sha256,
          'hot_head_event_hash_at_recording', v_hot_head_event_hash,
          'recorded_by', v_recorded_by,
          'authority_basis', v_authority_basis,
          'recorded_at', pg_catalog.to_char(
            v_recorded_at at time zone 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          )
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  insert into chlom_runtime.dail_cold_checkpoints_v1 (
    checkpoint_id,
    idempotency_key,
    source_event_count,
    source_min_sequence_id,
    source_max_sequence_id,
    source_head_event_hash,
    source_head_created_at,
    snapshot_created_at,
    snapshot_rpo_seconds,
    hot_event_count_at_recording,
    hot_max_sequence_id_at_recording,
    hot_head_event_hash_at_recording,
    hot_integrity_state,
    verification_checked_at,
    verification_failure_count,
    documented_correction_count,
    verifier_output,
    verifier_output_sha256,
    snapshot_manifest_sha256,
    snapshot_package_sha256,
    snapshot_object_ref,
    snapshot_bytes,
    storage_provider,
    encryption_state,
    custody_verified,
    readback_verified,
    restore_path_verified,
    receipt_dail_event_id,
    recorded_by,
    authority_basis,
    recorded_at,
    previous_checkpoint_receipt_sha256,
    checkpoint_receipt_sha256
  ) values (
    v_candidate_checkpoint_id,
    v_idempotency_key,
    p_source_event_count,
    v_source_min_sequence_id,
    p_source_max_sequence_id,
    v_source_head_hash,
    v_source_head_created_at,
    p_snapshot_created_at,
    v_snapshot_rpo_seconds,
    v_hot_event_count,
    v_hot_max_sequence_id,
    v_hot_head_event_hash,
    v_verification ->> 'integrity_state',
    (v_verification ->> 'checked_at')::timestamptz,
    (v_verification ->> 'failure_count')::integer,
    coalesce((v_verification ->> 'corrected_event_count')::integer, 0),
    v_verification,
    v_verifier_output_sha256,
    v_manifest_hash,
    v_package_hash,
    v_snapshot_object_ref,
    p_snapshot_bytes,
    p_storage_provider,
    p_encryption_state,
    true,
    true,
    true,
    p_receipt_dail_event_id,
    v_recorded_by,
    v_authority_basis,
    v_recorded_at,
    v_previous_checkpoint_receipt_sha256,
    v_checkpoint_receipt_sha256
  )
  on conflict (idempotency_key) do nothing
  returning checkpoint_id into v_checkpoint_id;

  if v_checkpoint_id is null then
    select c.*
      into strict v_existing
    from chlom_runtime.dail_cold_checkpoints_v1 c
    where c.idempotency_key = v_idempotency_key;

    if v_existing.source_event_count <> p_source_event_count
       or v_existing.source_max_sequence_id <> p_source_max_sequence_id
       or v_existing.source_head_event_hash <> v_source_head_hash
       or v_existing.snapshot_created_at <> p_snapshot_created_at
       or v_existing.snapshot_manifest_sha256 <> v_manifest_hash
       or v_existing.snapshot_package_sha256 <> v_package_hash
       or v_existing.snapshot_object_ref <> v_snapshot_object_ref
       or v_existing.snapshot_bytes <> p_snapshot_bytes
       or v_existing.storage_provider <> p_storage_provider
       or v_existing.encryption_state <> p_encryption_state
       or v_existing.receipt_dail_event_id is distinct from p_receipt_dail_event_id
       or v_existing.recorded_by <> v_recorded_by
       or v_existing.authority_basis <> v_authority_basis then
      raise exception 'idempotency key collision for DAIL cold checkpoint'
        using errcode = '23505';
    end if;
    v_checkpoint_id := v_existing.checkpoint_id;
    v_snapshot_rpo_seconds := v_existing.snapshot_rpo_seconds;
    v_verifier_output_sha256 := v_existing.verifier_output_sha256;
    v_previous_checkpoint_receipt_sha256 :=
      v_existing.previous_checkpoint_receipt_sha256;
    v_checkpoint_receipt_sha256 := v_existing.checkpoint_receipt_sha256;
  end if;

  return pg_catalog.jsonb_build_object(
    'checkpoint_id', v_checkpoint_id,
    'route', 'cold_recovery',
    'state', 'CHECKPOINT_CUSTODY_VERIFIED',
    'source_event_count', p_source_event_count,
    'source_max_sequence_id', p_source_max_sequence_id,
    'source_head_event_hash', v_source_head_hash,
    'hot_integrity_state', v_verification ->> 'integrity_state',
    'snapshot_rpo_seconds', v_snapshot_rpo_seconds,
    'verifier_output_sha256', v_verifier_output_sha256,
    'previous_checkpoint_receipt_sha256', v_previous_checkpoint_receipt_sha256,
    'checkpoint_receipt_sha256', v_checkpoint_receipt_sha256,
    'phase4_activation', false
  );
end
$function$;

create or replace function chlom_runtime.record_dail_recovery_drill_v1(
  p_idempotency_key text,
  p_checkpoint_id uuid,
  p_test_scope text,
  p_restore_target_class text,
  p_restore_environment_ref text,
  p_drill_started_at timestamptz,
  p_drill_completed_at timestamptz,
  p_restored_event_count bigint,
  p_restored_max_sequence_id bigint,
  p_restored_head_event_hash text,
  p_manifest_hash_verified boolean,
  p_package_hash_verified boolean,
  p_component_hashes_verified boolean,
  p_structured_data_parse_verified boolean,
  p_restore_path_verified boolean,
  p_cold_route_exercised boolean,
  p_hot_route_unchanged boolean,
  p_fault_injection_verified boolean,
  p_provider_exit_path_verified boolean,
  p_rollback_and_failback_verified boolean,
  p_recorded_by text,
  p_authority_basis text,
  p_receipt_dail_event_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set "TimeZone" = 'UTC'
as $function$
declare
  v_idempotency_key text := pg_catalog.btrim(p_idempotency_key);
  v_restore_environment_ref text := pg_catalog.btrim(p_restore_environment_ref);
  v_restored_head_event_hash text := pg_catalog.lower(
    pg_catalog.btrim(p_restored_head_event_hash)
  );
  v_recorded_by text := pg_catalog.btrim(p_recorded_by);
  v_authority_basis text := pg_catalog.btrim(p_authority_basis);
  v_checkpoint chlom_runtime.dail_cold_checkpoints_v1%rowtype;
  v_source_head_match boolean;
  v_observed_rpo_seconds bigint;
  v_observed_rto_seconds bigint;
  v_result text;
  v_drill_id uuid;
  v_existing chlom_runtime.dail_recovery_drill_receipts_v1%rowtype;
begin
  if v_idempotency_key is null
     or pg_catalog.length(v_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_checkpoint_id is null then
    raise exception 'checkpoint id is required' using errcode = '22023';
  end if;
  if p_test_scope not in ('metadata_manifest', 'ledger_lineage', 'full_data_restore') then
    raise exception 'unsupported recovery test scope' using errcode = '22023';
  end if;
  if p_restore_target_class is distinct from 'isolated_non_production' then
    raise exception 'recovery drills must use an isolated non-production target'
      using errcode = '22023';
  end if;
  if v_restore_environment_ref is null
     or pg_catalog.length(v_restore_environment_ref) not between 1 and 1024 then
    raise exception 'restore environment reference is invalid' using errcode = '22023';
  end if;
  if p_drill_started_at is null or p_drill_completed_at is null
     or p_drill_completed_at < p_drill_started_at
     or p_drill_completed_at > pg_catalog.clock_timestamp() + interval '5 minutes' then
    raise exception 'recovery drill timestamps are invalid' using errcode = '22023';
  end if;
  if p_restored_event_count is not null and p_restored_event_count < 0
     or p_restored_max_sequence_id is not null and p_restored_max_sequence_id < 0 then
    raise exception 'restored counts cannot be negative' using errcode = '22023';
  end if;
  if v_restored_head_event_hash is not null
     and v_restored_head_event_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'restored head hash must be a lowercase SHA-256 value'
      using errcode = '22023';
  end if;
  if v_recorded_by is null
     or pg_catalog.length(v_recorded_by) not between 1 and 255
     or v_authority_basis is null
     or pg_catalog.length(v_authority_basis) not between 1 and 1024 then
    raise exception 'recorder or authority basis is invalid' using errcode = '22023';
  end if;

  select c.*
    into strict v_checkpoint
  from chlom_runtime.dail_cold_checkpoints_v1 c
  where c.checkpoint_id = p_checkpoint_id;

  if p_drill_started_at < v_checkpoint.snapshot_created_at then
    raise exception 'recovery drill cannot predate the checkpoint snapshot'
      using errcode = '22023';
  end if;

  v_source_head_match := coalesce(
    p_restored_event_count = v_checkpoint.source_event_count
    and p_restored_max_sequence_id = v_checkpoint.source_max_sequence_id
    and v_restored_head_event_hash = v_checkpoint.source_head_event_hash,
    false
  );
  v_observed_rpo_seconds := pg_catalog.ceil(
    extract(epoch from p_drill_started_at - v_checkpoint.source_head_created_at)
  )::bigint;
  v_observed_rto_seconds := pg_catalog.ceil(
    extract(epoch from p_drill_completed_at - p_drill_started_at)
  )::bigint;

  v_result := case
    when v_source_head_match
      and p_manifest_hash_verified is true
      and p_package_hash_verified is true
      and p_component_hashes_verified is true
      and p_structured_data_parse_verified is true
      and p_restore_path_verified is true
      and p_cold_route_exercised is true
      and p_hot_route_unchanged is true
      and p_fault_injection_verified is true
      and p_provider_exit_path_verified is true
      and p_rollback_and_failback_verified is true
    then 'PASS'
    else 'FAIL'
  end;

  insert into chlom_runtime.dail_recovery_drill_receipts_v1 (
    idempotency_key,
    checkpoint_id,
    test_scope,
    restore_target_class,
    restore_environment_ref,
    drill_started_at,
    drill_completed_at,
    observed_rpo_seconds,
    observed_rto_seconds,
    restored_event_count,
    restored_max_sequence_id,
    restored_head_event_hash,
    source_head_match,
    manifest_hash_verified,
    package_hash_verified,
    component_hashes_verified,
    structured_data_parse_verified,
    restore_path_verified,
    cold_route_exercised,
    hot_route_unchanged,
    fault_injection_verified,
    provider_exit_path_verified,
    rollback_and_failback_verified,
    result,
    receipt_dail_event_id,
    recorded_by,
    authority_basis
  ) values (
    v_idempotency_key,
    p_checkpoint_id,
    p_test_scope,
    p_restore_target_class,
    v_restore_environment_ref,
    p_drill_started_at,
    p_drill_completed_at,
    v_observed_rpo_seconds,
    v_observed_rto_seconds,
    p_restored_event_count,
    p_restored_max_sequence_id,
    v_restored_head_event_hash,
    v_source_head_match,
    coalesce(p_manifest_hash_verified, false),
    coalesce(p_package_hash_verified, false),
    coalesce(p_component_hashes_verified, false),
    coalesce(p_structured_data_parse_verified, false),
    coalesce(p_restore_path_verified, false),
    coalesce(p_cold_route_exercised, false),
    coalesce(p_hot_route_unchanged, false),
    coalesce(p_fault_injection_verified, false),
    coalesce(p_provider_exit_path_verified, false),
    coalesce(p_rollback_and_failback_verified, false),
    v_result,
    p_receipt_dail_event_id,
    v_recorded_by,
    v_authority_basis
  )
  on conflict (idempotency_key) do nothing
  returning drill_id into v_drill_id;

  if v_drill_id is null then
    select r.*
      into strict v_existing
    from chlom_runtime.dail_recovery_drill_receipts_v1 r
    where r.idempotency_key = v_idempotency_key;

    if v_existing.checkpoint_id <> p_checkpoint_id
       or v_existing.test_scope <> p_test_scope
       or v_existing.restore_environment_ref <> v_restore_environment_ref
       or v_existing.drill_started_at <> p_drill_started_at
       or v_existing.drill_completed_at <> p_drill_completed_at
       or v_existing.restored_event_count is distinct from p_restored_event_count
       or v_existing.restored_max_sequence_id is distinct from p_restored_max_sequence_id
       or v_existing.restored_head_event_hash is distinct from v_restored_head_event_hash
       or v_existing.manifest_hash_verified is distinct from
          coalesce(p_manifest_hash_verified, false)
       or v_existing.package_hash_verified is distinct from
          coalesce(p_package_hash_verified, false)
       or v_existing.component_hashes_verified is distinct from
          coalesce(p_component_hashes_verified, false)
       or v_existing.structured_data_parse_verified is distinct from
          coalesce(p_structured_data_parse_verified, false)
       or v_existing.restore_path_verified is distinct from
          coalesce(p_restore_path_verified, false)
       or v_existing.cold_route_exercised is distinct from
          coalesce(p_cold_route_exercised, false)
       or v_existing.hot_route_unchanged is distinct from
          coalesce(p_hot_route_unchanged, false)
       or v_existing.fault_injection_verified is distinct from
          coalesce(p_fault_injection_verified, false)
       or v_existing.provider_exit_path_verified is distinct from
          coalesce(p_provider_exit_path_verified, false)
       or v_existing.rollback_and_failback_verified is distinct from
          coalesce(p_rollback_and_failback_verified, false)
       or v_existing.receipt_dail_event_id is distinct from p_receipt_dail_event_id
       or v_existing.recorded_by <> v_recorded_by
       or v_existing.authority_basis <> v_authority_basis
       or v_existing.result <> v_result then
      raise exception 'idempotency key collision for DAIL recovery drill'
        using errcode = '23505';
    end if;
    v_drill_id := v_existing.drill_id;
    v_source_head_match := v_existing.source_head_match;
    v_observed_rpo_seconds := v_existing.observed_rpo_seconds;
    v_observed_rto_seconds := v_existing.observed_rto_seconds;
    v_result := v_existing.result;
  end if;

  return pg_catalog.jsonb_build_object(
    'drill_id', v_drill_id,
    'checkpoint_id', p_checkpoint_id,
    'route', 'cold_recovery',
    'test_scope', p_test_scope,
    'result', v_result,
    'observed_rpo_seconds', v_observed_rpo_seconds,
    'observed_rto_seconds', v_observed_rto_seconds,
    'source_head_match', v_source_head_match,
    'phase4_activation', false
  );
end
$function$;

create or replace function chlom_runtime.read_dail_phase4_assurance_status_v1(
  p_max_checkpoint_age_seconds bigint default 93600
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set "TimeZone" = 'UTC'
as $function$
declare
  v_verification jsonb;
  v_hot_state text;
  v_checkpoint chlom_runtime.dail_cold_checkpoints_v1%rowtype;
  v_drill chlom_runtime.dail_recovery_drill_receipts_v1%rowtype;
  v_checkpoint_age_seconds bigint;
  v_cold_state text;
  v_assurance_state text;
begin
  if p_max_checkpoint_age_seconds is null
     or p_max_checkpoint_age_seconds <= 0
     or p_max_checkpoint_age_seconds > 604800 then
    raise exception 'checkpoint age threshold must be between 1 and 604800 seconds'
      using errcode = '22023';
  end if;

  v_verification := chlom_runtime.verify_dail_chain();
  v_hot_state := case
    when coalesce((v_verification ->> 'ok')::boolean, false)
         and coalesce((v_verification ->> 'failure_count')::integer, -1) = 0
      then 'PASS'
    else 'FAIL'
  end;

  select c.*
    into v_checkpoint
  from chlom_runtime.dail_cold_checkpoints_v1 c
  order by c.snapshot_created_at desc, c.recorded_at desc
  limit 1;

  if not found then
    v_cold_state := 'HOLD_NO_CHECKPOINT';
    v_assurance_state := 'HOLD';
    return pg_catalog.jsonb_build_object(
      'hot_route', pg_catalog.jsonb_build_object(
        'state', v_hot_state,
        'integrity_state', v_verification ->> 'integrity_state',
        'checked_events', (v_verification ->> 'checked_events')::bigint,
        'head_hash', v_verification ->> 'head_hash',
        'checked_at', v_verification ->> 'checked_at'
      ),
      'cold_route', pg_catalog.jsonb_build_object('state', v_cold_state),
      'component_phase4_assurance_state', v_assurance_state,
      'institutional_phase4_activation', false
    );
  end if;

  v_checkpoint_age_seconds := greatest(
    0,
    pg_catalog.ceil(
      extract(epoch from pg_catalog.clock_timestamp() - v_checkpoint.snapshot_created_at)
    )::bigint
  );

  select r.*
    into v_drill
  from chlom_runtime.dail_recovery_drill_receipts_v1 r
  where r.checkpoint_id = v_checkpoint.checkpoint_id
    and r.result = 'PASS'
  order by r.drill_completed_at desc
  limit 1;

  if v_checkpoint_age_seconds > p_max_checkpoint_age_seconds then
    v_cold_state := 'HOLD_STALE_CHECKPOINT';
  elsif not found then
    v_cold_state := 'HOLD_LATEST_CHECKPOINT_UNTESTED';
  else
    v_cold_state := case v_drill.test_scope
      when 'full_data_restore' then 'FULL_DATA_RECOVERY_VERIFIED'
      when 'ledger_lineage' then 'LEDGER_LINEAGE_RECOVERY_VERIFIED'
      else 'METADATA_RECOVERY_VERIFIED'
    end;
  end if;

  v_assurance_state := case
    when v_hot_state <> 'PASS' then 'HOLD_HOT_ROUTE'
    when v_cold_state = 'FULL_DATA_RECOVERY_VERIFIED'
      then 'READY_FOR_INDEPENDENT_PHASE4_READBACK'
    when v_cold_state in (
      'LEDGER_LINEAGE_RECOVERY_VERIFIED', 'METADATA_RECOVERY_VERIFIED'
    ) then 'BOUNDED_COLD_ASSURANCE_ONLY'
    else 'HOLD'
  end;

  return pg_catalog.jsonb_build_object(
    'hot_route', pg_catalog.jsonb_build_object(
      'state', v_hot_state,
      'integrity_state', v_verification ->> 'integrity_state',
      'checked_events', (v_verification ->> 'checked_events')::bigint,
      'head_hash', v_verification ->> 'head_hash',
      'checked_at', v_verification ->> 'checked_at'
    ),
    'cold_route', pg_catalog.jsonb_build_object(
      'state', v_cold_state,
      'checkpoint_id', v_checkpoint.checkpoint_id,
      'source_event_count', v_checkpoint.source_event_count,
      'source_max_sequence_id', v_checkpoint.source_max_sequence_id,
      'source_head_event_hash', v_checkpoint.source_head_event_hash,
      'checkpoint_receipt_sha256', v_checkpoint.checkpoint_receipt_sha256,
      'snapshot_created_at', v_checkpoint.snapshot_created_at,
      'checkpoint_age_seconds', v_checkpoint_age_seconds,
      'snapshot_rpo_seconds', v_checkpoint.snapshot_rpo_seconds,
      'last_passing_drill_id', v_drill.drill_id,
      'last_passing_test_scope', v_drill.test_scope,
      'last_passing_drill_completed_at', v_drill.drill_completed_at,
      'last_passing_drill_rpo_seconds', v_drill.observed_rpo_seconds,
      'last_passing_drill_rto_seconds', v_drill.observed_rto_seconds
    ),
    'component_phase4_assurance_state', v_assurance_state,
    'institutional_phase4_activation', false
  );
end
$function$;

comment on table chlom_runtime.dail_cold_checkpoints_v1 is
  'Append-only certified cold-checkpoint custody receipts; protected data path.';
comment on table chlom_runtime.dail_recovery_drill_receipts_v1 is
  'Append-only isolated DAIL recovery-drill receipts with explicit test scope.';
comment on function chlom_runtime.read_dail_phase4_assurance_status_v1(bigint) is
  'Service-role-only sanitized hot/cold readback; never an institutional Phase-4 activation claim.';

revoke all on function chlom_runtime.reject_dail_assurance_mutation_v1()
  from public, anon, authenticated, service_role;
revoke all on function chlom_runtime.record_dail_cold_checkpoint_v1(
  text, bigint, bigint, text, timestamptz, text, text, text, bigint,
  text, text, boolean, boolean, boolean, text, text, uuid
) from public, anon, authenticated;
revoke all on function chlom_runtime.record_dail_recovery_drill_v1(
  text, uuid, text, text, text, timestamptz, timestamptz, bigint, bigint,
  text, boolean, boolean, boolean, boolean, boolean, boolean, boolean,
  boolean, boolean, boolean, text, text, uuid
) from public, anon, authenticated;
revoke all on function chlom_runtime.read_dail_phase4_assurance_status_v1(bigint)
  from public, anon, authenticated;

grant execute on function chlom_runtime.record_dail_cold_checkpoint_v1(
  text, bigint, bigint, text, timestamptz, text, text, text, bigint,
  text, text, boolean, boolean, boolean, text, text, uuid
) to service_role, postgres;
grant execute on function chlom_runtime.record_dail_recovery_drill_v1(
  text, uuid, text, text, text, timestamptz, timestamptz, bigint, bigint,
  text, boolean, boolean, boolean, boolean, boolean, boolean, boolean,
  boolean, boolean, boolean, text, text, uuid
) to service_role, postgres;
grant execute on function chlom_runtime.read_dail_phase4_assurance_status_v1(bigint)
  to service_role, postgres;

-- The deployed chlom-mesh-status Edge Function calls this already-sanitized,
-- read-only wrapper with the anon key. Restore only that exact read route; no
-- mutation RPC receives an anon or authenticated grant here.
grant execute on function public.chlom_mesh_public_status_v1()
  to anon, authenticated, service_role;

commit;
