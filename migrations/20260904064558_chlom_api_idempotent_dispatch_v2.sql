begin;

create table if not exists chlom_protocol.api_idempotency_receipts_v1 (
  idempotency_receipt_id uuid primary key default gen_random_uuid(),
  operator_user_id uuid not null,
  operator_subject_id text not null,
  action text not null,
  idempotency_key_hash text not null check (
    idempotency_key_hash ~ '^[0-9a-f]{64}$'
  ),
  request_payload_sha256 text not null check (
    request_payload_sha256 ~ '^[0-9a-f]{64}$'
  ),
  dispatch_receipt_id uuid,
  dispatch_request_id uuid,
  result_sha256 text not null check (result_sha256 ~ '^[0-9a-f]{64}$'),
  result jsonb not null,
  recorded_at timestamptz not null default now(),
  unique (operator_user_id, action, idempotency_key_hash)
);

create index if not exists api_idempotency_receipts_v1_subject_idx
  on chlom_protocol.api_idempotency_receipts_v1(
    operator_subject_id,
    recorded_at desc
  );

alter table chlom_protocol.api_idempotency_receipts_v1 enable row level security;
alter table chlom_protocol.api_idempotency_receipts_v1 force row level security;

revoke all on chlom_protocol.api_idempotency_receipts_v1
  from public, anon, authenticated;
grant all on chlom_protocol.api_idempotency_receipts_v1 to service_role;

drop trigger if exists api_idempotency_receipts_v1_append_only
  on chlom_protocol.api_idempotency_receipts_v1;
create trigger api_idempotency_receipts_v1_append_only
before update or delete on chlom_protocol.api_idempotency_receipts_v1
for each row execute function chlom_protocol.reject_append_only_mutation_v1();

create or replace function public.chlom_api_dispatch_v2(
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog', 'chlom_protocol', 'chlom_runtime', 'public', 'auth', 'extensions'
as $$
declare
  v_uid uuid := auth.uid();
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_mutation boolean;
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_key_hash text;
  v_payload_sha text;
  v_operator_subject text;
  v_prior chlom_protocol.api_idempotency_receipts_v1%rowtype;
  v_result jsonb;
  v_result_sha text;
begin
  if v_uid is null then
    raise exception using
      errcode = '28000',
      message = 'CHLOM_API_AUTHENTICATION_REQUIRED';
  end if;

  v_mutation := v_action not in ('status', 'capabilities');

  if not v_mutation then
    return public.chlom_api_dispatch_v1(v_action, v_payload);
  end if;

  if v_key is null then
    raise exception using
      errcode = '22023',
      message = 'CHLOM_API_IDEMPOTENCY_KEY_REQUIRED';
  end if;

  if length(v_key) > 128 then
    raise exception using
      errcode = '22023',
      message = 'CHLOM_API_IDEMPOTENCY_KEY_TOO_LONG';
  end if;

  select o.operator_subject_id
    into v_operator_subject
  from chlom_protocol.api_operator_versions_v1 o
  where o.user_id = v_uid
  order by o.version desc, o.recorded_at desc
  limit 1;

  if v_operator_subject is null then
    raise exception using
      errcode = '42501',
      message = 'CHLOM_API_OPERATOR_NOT_ACTIVE';
  end if;

  v_key_hash := encode(
    extensions.digest(convert_to(v_key, 'UTF8'), 'sha256'),
    'hex'
  );
  v_payload_sha := chlom_protocol.canonical_sha256_v1(v_payload);

  perform pg_advisory_xact_lock(
    hashtextextended(
      v_uid::text || ':' || v_action || ':' || v_key_hash,
      0
    )
  );

  select r.*
    into v_prior
  from chlom_protocol.api_idempotency_receipts_v1 r
  where r.operator_user_id = v_uid
    and r.action = v_action
    and r.idempotency_key_hash = v_key_hash
  limit 1;

  if found then
    if v_prior.request_payload_sha256 <> v_payload_sha then
      raise exception using
        errcode = '23505',
        message = 'CHLOM_API_IDEMPOTENCY_CONFLICT';
    end if;

    return v_prior.result || jsonb_build_object(
      'idempotent_replay', true,
      'idempotency_receipt_id', v_prior.idempotency_receipt_id,
      'first_recorded_at', v_prior.recorded_at
    );
  end if;

  v_result := public.chlom_api_dispatch_v1(v_action, v_payload);
  v_result_sha := chlom_protocol.canonical_sha256_v1(v_result);

  insert into chlom_protocol.api_idempotency_receipts_v1 (
    operator_user_id,
    operator_subject_id,
    action,
    idempotency_key_hash,
    request_payload_sha256,
    dispatch_receipt_id,
    dispatch_request_id,
    result_sha256,
    result
  ) values (
    v_uid,
    v_operator_subject,
    v_action,
    v_key_hash,
    v_payload_sha,
    nullif(v_result->>'dispatch_receipt_id', '')::uuid,
    nullif(v_result->>'request_id', '')::uuid,
    v_result_sha,
    v_result
  )
  returning idempotency_receipt_id
    into v_prior.idempotency_receipt_id;

  return v_result || jsonb_build_object(
    'idempotent_replay', false,
    'idempotency_receipt_id', v_prior.idempotency_receipt_id
  );
end
$$;

revoke all on function public.chlom_api_dispatch_v2(text, jsonb, text)
  from public, anon;
grant execute on function public.chlom_api_dispatch_v2(text, jsonb, text)
  to authenticated, service_role;

comment on function public.chlom_api_dispatch_v2(text, jsonb, text) is
'Authenticated CHLOM control-plane dispatcher with transaction-scoped advisory locking and append-only idempotency receipts. Mutation actions require an idempotency key. External money movement, production mint confirmation, tokenomics activation, validator activation and public-chain anchor confirmation remain excluded by v1 allowlisting.';

commit;
