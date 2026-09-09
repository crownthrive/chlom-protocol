begin;

DO $operator_enrollment$
declare
  v_user_id uuid;
  v_subject text := 'ct.subject.founder.kavonte-jones-sr';
  v_approval text := 'ct.approval.chlom-production-realization.2026-09-04';
  v_scopes text[] := array[
    'chlom:read',
    'chlom:write',
    'chlom:settlement-preview',
    'chlom:token-candidate',
    'chlom:oracle',
    'chlom:proof'
  ];
  v_canonical jsonb;
  v_hash text;
  v_event jsonb;
begin
  select u.id
    into v_user_id
  from auth.users u
  where lower(u.email) = 'contact@crownthrive.com'
    and u.email_confirmed_at is not null
  order by u.created_at
  limit 1;

  if v_user_id is null then
    raise exception 'CHLOM_FOUNDER_ACCOUNT_NOT_CONFIRMED';
  end if;

  if not exists (
    select 1
    from chlom_protocol.api_operator_versions_v1
    where operator_subject_id = v_subject
      and version = 1
  ) then
    v_canonical := jsonb_build_object(
      'contract', 'ct.chlom.api-operator-version.v1',
      'operator_subject_id', v_subject,
      'version', 1,
      'user_id', v_user_id,
      'authority_class', 'D3',
      'active', true,
      'scopes', to_jsonb(v_scopes),
      'approval_id', v_approval,
      'control_plane_scope', 'INTERNAL_ONLY',
      'external_execution_enabled', false
    );

    v_hash := chlom_protocol.canonical_sha256_v1(v_canonical);

    v_event := chlom_runtime.append_dail_event(
      'chlom.api.operator.version.recorded',
      'chlom_api_operator',
      v_subject,
      v_canonical || jsonb_build_object(
        'record_hash', v_hash,
        'raw_credentials_recorded', false
      ),
      v_subject,
      null,
      'ct.ops.agent.chlom-api',
      '1.0.0',
      'ctcorr:chlom-api-operator:' || v_subject || ':1',
      null,
      'FOUNDER_DIRECTIVE_2026-09-04',
      v_approval,
      'restricted'
    );

    insert into chlom_protocol.api_operator_versions_v1 (
      operator_subject_id,
      version,
      user_id,
      authority_class,
      active,
      scopes,
      previous_record_hash,
      record_hash,
      approval_id,
      evidence,
      dail_event_id,
      dail_sequence_id,
      dail_event_hash,
      recorded_by
    ) values (
      v_subject,
      1,
      v_user_id,
      'D3',
      true,
      v_scopes,
      null,
      v_hash,
      v_approval,
      jsonb_build_object(
        'email_identity', 'contact@crownthrive.com',
        'email_confirmed', true,
        'control_plane_scope', 'INTERNAL_ONLY',
        'external_execution_enabled', false,
        'raw_credentials_recorded', false
      ),
      (v_event->>'event_id')::uuid,
      (v_event->>'sequence_id')::bigint,
      v_event->>'event_hash',
      v_subject
    );
  end if;
end
$operator_enrollment$;

commit;
