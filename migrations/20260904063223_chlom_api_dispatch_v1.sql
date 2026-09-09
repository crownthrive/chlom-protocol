begin;

create or replace function public.chlom_api_dispatch_v1(
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog', 'chlom_protocol', 'chlom_runtime', 'public', 'auth', 'extensions'
as $$
declare
  v_uid uuid := auth.uid();
  v_operator chlom_protocol.api_operator_versions_v1%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_required_scope text;
  v_required_authority text;
  v_request_id uuid := gen_random_uuid();
  v_result jsonb;
  v_result_sha text;
  v_receipt_event jsonb;
  v_dispatch_receipt_id uuid := gen_random_uuid();
  v_server_payload jsonb;
  v_mutation boolean := true;
begin
  if v_uid is null then
    raise exception using
      errcode = '28000',
      message = 'CHLOM_API_AUTHENTICATION_REQUIRED';
  end if;

  if octet_length(v_payload::text) > 1048576 then
    raise exception using
      errcode = '22023',
      message = 'CHLOM_API_PAYLOAD_TOO_LARGE';
  end if;

  select o.*
    into v_operator
  from chlom_protocol.api_operator_versions_v1 o
  where o.user_id = v_uid
  order by o.version desc, o.recorded_at desc
  limit 1;

  if not found or not v_operator.active then
    raise exception using
      errcode = '42501',
      message = 'CHLOM_API_OPERATOR_NOT_ACTIVE';
  end if;

  case v_action
    when 'status' then
      v_required_scope := 'chlom:read';
      v_required_authority := 'D0';
      v_mutation := false;
    when 'capabilities' then
      v_required_scope := 'chlom:read';
      v_required_authority := 'D0';
      v_mutation := false;
    when 'register_asset_binding' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D1';
    when 'record_ownership_interest' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_rights_instrument' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_dla' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_lex_offer' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_agreement_entitlement' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_obligation' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'record_revenue_policy' then
      v_required_scope := 'chlom:write';
      v_required_authority := 'D2';
    when 'preview_settlement' then
      v_required_scope := 'chlom:settlement-preview';
      v_required_authority := 'D2';
    when 'register_token_candidate' then
      v_required_scope := 'chlom:token-candidate';
      v_required_authority := 'D2';
    when 'report_oracle_signal' then
      v_required_scope := 'chlom:oracle';
      v_required_authority := 'D1';
    when 'bind_dail_proof' then
      v_required_scope := 'chlom:proof';
      v_required_authority := 'D1';
    else
      raise exception using
        errcode = '22023',
        message = 'CHLOM_API_ACTION_NOT_ALLOWED';
  end case;

  if not (
    v_required_scope = any(v_operator.scopes)
    or 'chlom:*' = any(v_operator.scopes)
  ) then
    raise exception using
      errcode = '42501',
      message = 'CHLOM_API_SCOPE_DENIED';
  end if;

  if chlom_protocol.authority_rank_v1(v_operator.authority_class)
     < chlom_protocol.authority_rank_v1(v_required_authority) then
    raise exception using
      errcode = '42501',
      message = 'CHLOM_API_AUTHORITY_DENIED';
  end if;

  if not v_mutation then
    if v_action = 'status' then
      return public.chlom_protocol_status_v1();
    end if;
    return public.chlom_api_capabilities_v1();
  end if;

  v_server_payload := v_payload || jsonb_build_object(
    'recorded_by', v_operator.operator_subject_id,
    'created_by', v_operator.operator_subject_id,
    'oracle_subject_id', v_operator.operator_subject_id,
    'authority_class', v_operator.authority_class,
    'authority_basis', 'CHLOM_AUTHENTICATED_OPERATOR_V1',
    'approval_id', v_operator.approval_id,
    'correlation_id', 'ctcorr:chlom-api:' || v_request_id::text
  );

  case v_action
    when 'register_asset_binding' then
      v_result := chlom_protocol.register_asset_binding_v1(v_server_payload);
    when 'record_ownership_interest' then
      v_result := chlom_protocol.record_ownership_interest_v1(v_server_payload);
    when 'record_rights_instrument' then
      v_result := chlom_protocol.record_rights_instrument_v1(v_server_payload);
    when 'record_dla' then
      v_result := chlom_protocol.record_dla_v1(v_server_payload);
    when 'record_lex_offer' then
      v_result := chlom_protocol.record_lex_offer_v1(v_server_payload);
    when 'record_agreement_entitlement' then
      v_result := chlom_protocol.record_agreement_entitlement_v1(v_server_payload);
    when 'record_obligation' then
      v_result := chlom_protocol.record_obligation_v1(v_server_payload);
    when 'record_revenue_policy' then
      v_result := chlom_protocol.record_revenue_policy_v1(v_server_payload);
    when 'preview_settlement' then
      v_result := chlom_protocol.preview_settlement_v1(v_server_payload);
    when 'register_token_candidate' then
      v_result := chlom_protocol.register_token_candidate_v1(v_server_payload);
    when 'report_oracle_signal' then
      v_result := chlom_protocol.report_oracle_signal_v1(v_server_payload);
    when 'bind_dail_proof' then
      v_result := chlom_protocol.bind_dail_proof_v1(v_server_payload);
  end case;

  v_result_sha := chlom_protocol.canonical_sha256_v1(v_result);

  v_receipt_event := chlom_runtime.append_dail_event(
    'chlom.api.dispatch.completed',
    'chlom_api_dispatch',
    v_dispatch_receipt_id::text,
    jsonb_build_object(
      'contract', 'ct.chlom.authenticated-api-dispatch-receipt.v1',
      'request_id', v_request_id,
      'operator_subject_id', v_operator.operator_subject_id,
      'action', v_action,
      'required_scope', v_required_scope,
      'required_authority_class', v_required_authority,
      'result_sha256', v_result_sha,
      'raw_request_payload_recorded', false,
      'external_execution_enabled', false
    ),
    v_operator.operator_subject_id,
    null,
    'ct.ops.agent.chlom-api',
    '1.0.0',
    'ctcorr:chlom-api:' || v_request_id::text,
    coalesce(
      v_result->'dail'->>'event_id',
      v_result->'entitlement_dail'->>'event_id',
      v_result->'agreement_dail'->>'event_id'
    ),
    'CHLOM_AUTHENTICATED_OPERATOR_V1',
    v_operator.approval_id,
    'restricted'
  );

  insert into chlom_protocol.api_dispatch_receipts_v1 (
    dispatch_receipt_id,
    request_id,
    operator_subject_id,
    operator_user_id,
    action,
    required_scope,
    required_authority_class,
    result_sha256,
    result_state,
    dail_event_id,
    dail_sequence_id,
    dail_event_hash
  ) values (
    v_dispatch_receipt_id,
    v_request_id,
    v_operator.operator_subject_id,
    v_uid,
    v_action,
    v_required_scope,
    v_required_authority,
    v_result_sha,
    coalesce(v_result->>'state', v_result->>'result', 'RECORDED'),
    (v_receipt_event->>'event_id')::uuid,
    (v_receipt_event->>'sequence_id')::bigint,
    v_receipt_event->>'event_hash'
  );

  return jsonb_build_object(
    'ok', coalesce((v_result->>'ok')::boolean, true),
    'contract', 'ct.chlom.authenticated-control-plane-dispatch.v1',
    'request_id', v_request_id,
    'dispatch_receipt_id', v_dispatch_receipt_id,
    'action', v_action,
    'result_sha256', v_result_sha,
    'result', v_result,
    'receipt_dail', v_receipt_event,
    'external_execution_enabled', false
  );
end
$$;

revoke all on function public.chlom_api_dispatch_v1(text, jsonb)
  from public, anon;
grant execute on function public.chlom_api_dispatch_v1(text, jsonb)
  to authenticated, service_role;

comment on function public.chlom_api_dispatch_v1(text, jsonb) is
'Authenticated allowlisted CHLOM internal control-plane dispatcher. Server binds actor, authority, approval and correlation. External minting, money movement, validator activation and public anchor confirmation are absent.';

commit;
