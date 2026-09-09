begin;

create or replace function public.chlom_api_capabilities_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = 'pg_catalog', 'chlom_protocol', 'auth'
as $$
declare
  v_uid uuid := auth.uid();
  v_operator chlom_protocol.api_operator_versions_v1%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object(
      'ok', false,
      'state', 'AUTHENTICATION_REQUIRED',
      'external_execution_enabled', false
    );
  end if;

  select o.*
    into v_operator
  from chlom_protocol.api_operator_versions_v1 o
  where o.user_id = v_uid
  order by o.version desc, o.recorded_at desc
  limit 1;

  if not found or not v_operator.active then
    return jsonb_build_object(
      'ok', false,
      'state', 'OPERATOR_NOT_ACTIVE',
      'external_execution_enabled', false
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'contract', 'ct.chlom.authenticated-control-plane-capabilities.v1',
    'operator_subject_id', v_operator.operator_subject_id,
    'operator_version', v_operator.version,
    'authority_class', v_operator.authority_class,
    'scopes', to_jsonb(v_operator.scopes),
    'allowed_actions', jsonb_build_array(
      'status',
      'capabilities',
      'register_asset_binding',
      'record_ownership_interest',
      'record_rights_instrument',
      'record_dla',
      'record_lex_offer',
      'record_agreement_entitlement',
      'record_obligation',
      'record_revenue_policy',
      'preview_settlement',
      'register_token_candidate',
      'report_oracle_signal',
      'bind_dail_proof'
    ),
    'explicitly_excluded_actions', jsonb_build_array(
      'external_money_movement',
      'production_token_mint_confirmation',
      'tokenomics_activation',
      'validator_activation',
      'public_chain_anchor_confirmation',
      'legal_title_adjudication'
    ),
    'external_execution_enabled', false,
    'observed_at', clock_timestamp()
  );
end
$$;

revoke all on function public.chlom_api_capabilities_v1()
  from public, anon;
grant execute on function public.chlom_api_capabilities_v1()
  to authenticated, service_role;

comment on function public.chlom_api_capabilities_v1() is
'Authenticated CHLOM operator capabilities. External money movement, mint confirmation, validator activation, tokenomics activation and public anchor confirmation remain excluded.';

commit;
