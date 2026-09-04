create or replace function public.chlom_api_dispatch_v3(
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','chlom_protocol','chlom_runtime','public','auth','extensions'
as $$
declare
  v_uid uuid := auth.uid();
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_mutation boolean := v_action not in ('status', 'capabilities');
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_request_sha text;
  v_existing chlom_protocol.api_idempotency_registry_v1%rowtype;
  v_bucket timestamptz := date_trunc('minute', clock_timestamp());
  v_count integer;
  v_limit integer;
  v_result jsonb;
  v_response_sha text;
begin
  if v_uid is null then
    raise exception using errcode='28000', message='CHLOM_API_AUTHENTICATION_REQUIRED';
  end if;
  if octet_length(v_payload::text) > 1048576 then
    raise exception using errcode='22023', message='CHLOM_API_PAYLOAD_TOO_LARGE';
  end if;

  v_limit := case when v_mutation then 30 else 120 end;
  insert into chlom_protocol.api_rate_buckets_v1(
    operator_user_id, action, bucket_started_at, request_count, updated_at
  ) values(v_uid, v_action, v_bucket, 1, clock_timestamp())
  on conflict(operator_user_id, action,bucket_started_at)
  do update set request_count=chlom_protocol.api_rate_buckets_v1.request_count+1,
                updated_at=excluded.updated_at
  returning request_count into v_count;

  if v_count > v_limit then
    raise exception using errcode='54000', message='CHLOM_API_RATE_LIMIT_EXCEEDED';
  end if;

  if not v_mutation then
    return public.chlom_api_dispatch_v1(v_action, v_payload)
      || jsonb_build_object(
        'dispatcher_contract','ct.chlom.authenticated-control-plane-dispatch.v3',
        'idempotency_required',false,
        'rate_limit_per_minute',v_limit
      );
  end if;

  if v_key = '' or length(v_key) < 16 or length(v_key) > 128
     or v_key !~ '^[A-Za-z0-9._:-]+$' then
    raise exception using errcode='22023', message='CHLOM_API_IDEMPOTENCY_KEY_REQUIRED';
  end if;

  v_request_sha := chlom_protocol.canonical_sha256_v1(
    jsonb_build_object('action', v_action, 'payload', v_payload)
  );

  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':' || v_key, 0)
  );

  select r.* into v_existing
  from chlom_protocol.api_idempotency_registry_v1 r
  where r.operator_user_id=v_uid and r.idempotency_key=v_key
  limit 1;

  if found then
    if v_existing.action <> v_action or v_existing.request_sha256 <> v_request_sha then
      raise exception using errcode='23505', message='CHLOM_API_IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.state='COMPLETED' and v_existing.response is not null then
      return v_existing.response || jsonb_build_object(
        'dispatcher_contract','ct.chlom.authenticated-control-plane-dispatch.v3',
        'idempotent_replay',true,
        'idempotency_key',v_key,
        'idempotency_response_sha256',v_existing.response_sha256,
        'first_seen_at',v_existing.first_seen_at,
        'rate_limit_per_minute',v_limit
      );
    end if;
    raise exception using errcode='55000', message='CHLOM_API_REQUEST_IN_PROGRESS';
  end if;

  insert into chlom_protocol.api_idempotency_registry_v1(
    operator_user_id,idempotency_key,action,request_sha256,state
  ) values(v_uid,v_key,v_action,v_request_sha,'PROCESSING');

  v_result := public.chlom_api_dispatch_v1(v_action,v_payload);
  v_response_sha := chlom_protocol.canonical_sha256_v1(v_result);

  update chlom_protocol.api_idempotency_registry_v1
  set state='COMPLETED',response=v_result,response_sha256=v_response_sha,completed_at=clock_timestamp()
  where operator_user_id=v_uid and idempotency_key=v_key;

  return v_result || jsonb_build_object(
    'dispatcher_contract','ct.chlom.authenticated-control-plane-dispatch.v3',
    'idempotency_key',v_key,
    'idempotency_response_sha256',v_response_sha,
    'idempotent_replay',false,
    'rate_limit_per_minute',v_limit
  );
end
$$;

revoke all on function public.chlom_api_dispatch_v3(text,jsonb,text) from public,anon;
grant execute on function public.chlom_api_dispatch_v3(text,jsonb,text) to authenticated,service_role;

comment on function public.chlom_api_dispatch_v3(text,jsonb,text) is
'Read-safe, replay-safe authenticated CHLOM dispatcher. Status and capabilities are rate-limited reads without idempotency keys. Mutations require caller-scoped idempotency, advisory locking, conflict detection, append-only v1 dispatch receipts, and bounded per-minute request limits. External money movement, production mint confirmation, tokenomics activation, validator activation and public-chain anchor confirmation remain excluded.';
