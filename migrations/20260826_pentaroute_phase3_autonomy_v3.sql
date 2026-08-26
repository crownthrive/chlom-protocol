-- PentaRoute Phase 3 autonomous supervisor
-- Applied to CrownThrive ThriveBase on 2026-08-26.
-- Authority ceiling: A2 / D2. D3 and destructive/provider-authority decisions remain human governed.

create table if not exists integration_control.pentaroute_autonomy_runs_v3 (
  run_id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  state text not null default 'RUNNING',
  healed_jobs text[] not null default '{}'::text[],
  stale_jobs text[] not null default '{}'::text[],
  checks jsonb not null default '{}'::jsonb,
  phase3_snapshot jsonb,
  pentaroute_snapshot jsonb,
  factory_snapshot jsonb,
  error text,
  metadata jsonb not null default '{}'::jsonb
);

alter table integration_control.pentaroute_autonomy_runs_v3 enable row level security;
revoke all on integration_control.pentaroute_autonomy_runs_v3 from public, anon, authenticated;
grant select on integration_control.pentaroute_autonomy_runs_v3 to service_role;

insert into penta_runtime.agent_registry_v1 (
  agent_id, canonical_name, owner_component_key, role,
  autonomy_ceiling, decision_ceiling, vote_eligible, self_approval,
  status, capabilities, metadata, updated_at
) values (
  'ct.penta.agent.route',
  'PentaRoute Agent',
  'penta.route',
  'Phase 3 routing, liveness, scheduler supervision, and bounded recovery dispatch',
  'A2', 'D2', false, false, 'active',
  array['route','observe','heartbeat','scheduler_supervise','bounded_recovery','factory_reentry','phase3_reentry','evidence_record'],
  jsonb_build_object(
    'contract','ct.penta.route.agent.v3',
    'phase',3,
    'operation_default','deny_until_certified',
    'd3_human_governance',true,
    'universal_delete',false,
    'provider_authority_manufacture',false
  ),
  now()
)
on conflict (agent_id) do update set
  canonical_name=excluded.canonical_name,
  owner_component_key=excluded.owner_component_key,
  role=excluded.role,
  autonomy_ceiling=excluded.autonomy_ceiling,
  decision_ceiling=excluded.decision_ceiling,
  vote_eligible=excluded.vote_eligible,
  self_approval=excluded.self_approval,
  status=excluded.status,
  capabilities=excluded.capabilities,
  metadata=excluded.metadata,
  updated_at=now();

insert into integration_control.pentaroute_components_v3 (
  component_key, canonical_name, role, http_method, function_slug,
  phase, contract_version, state, max_auto_risk, mutation_allowed,
  requires_certified_operation, healthcheck_enabled, metadata, updated_at
) values (
  'pentarouteautonomy',
  'PentaRoute Autonomy',
  'phase3_autonomy_supervisor',
  null,
  'pentaroute-autonomy-v3',
  3,
  'v3',
  'active',
  'D2',
  false,
  false,
  true,
  jsonb_build_object(
    'provider_mutation',false,
    'scheduler_supervision',true,
    'bounded_recovery',true,
    'd3_human_governance',true,
    'universal_delete',false,
    'self_approval',false
  ),
  now()
)
on conflict (component_key) do update set
  canonical_name=excluded.canonical_name,
  role=excluded.role,
  http_method=excluded.http_method,
  function_slug=excluded.function_slug,
  phase=excluded.phase,
  contract_version=excluded.contract_version,
  state=excluded.state,
  max_auto_risk=excluded.max_auto_risk,
  mutation_allowed=excluded.mutation_allowed,
  requires_certified_operation=excluded.requires_certified_operation,
  healthcheck_enabled=excluded.healthcheck_enabled,
  metadata=excluded.metadata,
  updated_at=now();

insert into integration_control.phase3_runtime_assets_v3 (
  asset_key, asset_type, runtime_ref, phase, current_contract_version,
  observed_runtime_version, state, privilege_state, previous_version_refs,
  metadata, last_observed_at
) values (
  'ct.runtime.pentaroute-autonomy-v3',
  'edge_function',
  'pentaroute-autonomy-v3',
  3,
  'v3',
  '1',
  'active',
  'governed_by_pentaroute_v3',
  '[]'::jsonb,
  jsonb_build_object(
    'family','PentaRoute',
    'component','PentaRoute Autonomy',
    'role','phase3_autonomy_supervisor',
    'max_auto_risk','D2',
    'provider_mutation',false,
    'd3_human_governance',true,
    'universal_delete',false
  ),
  now()
)
on conflict (asset_key) do update set
  asset_type=excluded.asset_type,
  runtime_ref=excluded.runtime_ref,
  phase=excluded.phase,
  current_contract_version=excluded.current_contract_version,
  observed_runtime_version=excluded.observed_runtime_version,
  state=excluded.state,
  privilege_state=excluded.privilege_state,
  metadata=excluded.metadata,
  last_observed_at=now();

create or replace function integration_control.pentaroute_autonomy_status_v3()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_schedulers jsonb;
  v_factory jsonb;
  v_agent jsonb;
  v_last_run jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'jobname', q.jobname,
    'jobid', j.jobid,
    'active', coalesce(j.active,false),
    'schedule', j.schedule,
    'last_success', (select max(r.end_time) from cron.job_run_details r where r.jobid=j.jobid and r.status='succeeded'),
    'latest_status', (select r.status from cron.job_run_details r where r.jobid=j.jobid order by r.start_time desc limit 1)
  ) order by q.jobname), '[]'::jsonb)
  into v_schedulers
  from (values
    ('ct-software-factory-dispatch-v3'),
    ('ct-software-factory-continuity-v5'),
    ('ct-software-factory-tick-v2'),
    ('ct-phase3-self-discovery-v3'),
    ('ct-phase3-bounded-write-convergence-v3'),
    ('pentabeata-heartbeat-v3'),
    ('ct-pentaroute-autonomy-v3')
  ) as q(jobname)
  left join cron.job j on j.jobname=q.jobname;

  select coalesce(jsonb_object_agg(certification_state, cnt), '{}'::jsonb)
  into v_factory
  from (
    select certification_state, count(*)::int as cnt
    from public.ct_factory_adapter_certification_queue
    group by certification_state
  ) f;

  select to_jsonb(a) - 'created_at' - 'updated_at'
  into v_agent
  from penta_runtime.agent_registry_v1 a
  where a.agent_id='ct.penta.agent.route';

  select to_jsonb(r)
  into v_last_run
  from integration_control.pentaroute_autonomy_runs_v3 r
  order by r.started_at desc
  limit 1;

  return jsonb_build_object(
    'service','ct.pentaroute.autonomy.v3',
    'name','PentaRoute Autonomy',
    'phase',3,
    'contract_version','v3',
    'state','ACTIVE_AUTONOMOUS',
    'generated_at',now(),
    'agent',v_agent,
    'schedulers',v_schedulers,
    'factory_certification_queue',v_factory,
    'pentaroute',public.pentaroute_status_v3(),
    'phase3',public.ct_phase3_project_status_v3(),
    'last_run',v_last_run,
    'guardrails',jsonb_build_object(
      'autonomy_ceiling','A2',
      'max_auto_risk','D2',
      'self_approval',false,
      'd3_human_governance',true,
      'universal_delete',false,
      'uncertified_provider_mutations',false,
      'money_movement_authority',false
    )
  );
end;
$$;

revoke all on function integration_control.pentaroute_autonomy_status_v3() from public, anon, authenticated;
grant execute on function integration_control.pentaroute_autonomy_status_v3() to service_role;

create or replace function integration_control.pentaroute_autonomy_cycle_v3()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id uuid := gen_random_uuid();
  v_job record;
  v_existing record;
  v_last_success timestamptz;
  v_latest_status text;
  v_needs_recovery boolean;
  v_reason text;
  v_recovery jsonb;
  v_checks jsonb := '{}'::jsonb;
  v_healed text[] := '{}'::text[];
  v_stale text[] := '{}'::text[];
  v_phase3 jsonb;
  v_pentaroute jsonb;
  v_factory jsonb;
  v_state text := 'OPERATIONAL';
  v_err text;
begin
  insert into integration_control.pentaroute_autonomy_runs_v3(run_id,state,metadata)
  values (v_run_id,'RUNNING',jsonb_build_object('contract','ct.penta.route.autonomy.v3','phase',3));

  for v_job in
    select * from (values
      ('ct-software-factory-dispatch-v3','* * * * *','select public.ct_factory_dispatch_tick();',interval '4 minutes'),
      ('ct-software-factory-continuity-v5','*/2 * * * *','select public.ct_factory_continuity_cycle(1);',interval '7 minutes'),
      ('ct-software-factory-tick-v2','*/5 * * * *','select public.ct_factory_tick();',interval '12 minutes'),
      ('ct-phase3-self-discovery-v3','*/5 * * * *','select public.ct_phase3_self_discovery_tick_v3();',interval '12 minutes'),
      ('ct-phase3-bounded-write-convergence-v3','*/5 * * * *','select integration_control.phase3_converge_all_bounded_writes_v3();',interval '12 minutes'),
      ('pentabeata-heartbeat-v3','*/5 * * * *','select public.pentaroute_status_v3();',interval '12 minutes')
    ) as x(jobname,schedule,command,stale_after)
  loop
    select j.* into v_existing from cron.job j where j.jobname=v_job.jobname limit 1;
    v_needs_recovery := false;
    v_reason := null;
    v_recovery := null;

    if v_existing.jobid is null then
      perform cron.schedule(v_job.jobname,v_job.schedule,v_job.command);
      v_healed := array_append(v_healed,v_job.jobname);
      v_needs_recovery := true;
      v_reason := 'scheduler_recreated';
      select j.* into v_existing from cron.job j where j.jobname=v_job.jobname limit 1;
    elsif not v_existing.active then
      perform cron.alter_job(job_id => v_existing.jobid, active => true);
      v_healed := array_append(v_healed,v_job.jobname);
      v_needs_recovery := true;
      v_reason := 'scheduler_reactivated';
    end if;

    select max(r.end_time) into v_last_success
    from cron.job_run_details r
    where r.jobid=v_existing.jobid and r.status='succeeded';

    select r.status into v_latest_status
    from cron.job_run_details r
    where r.jobid=v_existing.jobid
    order by r.start_time desc
    limit 1;

    if v_last_success is null or v_last_success < now() - v_job.stale_after or v_latest_status='failed' then
      v_stale := array_append(v_stale,v_job.jobname);
      v_needs_recovery := true;
      if v_reason is null then v_reason := 'stale_or_failed'; end if;
    end if;

    if v_needs_recovery then
      begin
        case v_job.jobname
          when 'ct-software-factory-dispatch-v3' then v_recovery := public.ct_factory_dispatch_tick();
          when 'ct-software-factory-continuity-v5' then v_recovery := public.ct_factory_continuity_cycle(1);
          when 'ct-software-factory-tick-v2' then v_recovery := public.ct_factory_tick();
          when 'ct-phase3-self-discovery-v3' then v_recovery := public.ct_phase3_self_discovery_tick_v3();
          when 'ct-phase3-bounded-write-convergence-v3' then v_recovery := integration_control.phase3_converge_all_bounded_writes_v3();
          when 'pentabeata-heartbeat-v3' then v_recovery := public.pentaroute_status_v3();
          else v_recovery := jsonb_build_object('skipped',true);
        end case;
      exception when others then
        v_state := 'DEGRADED';
        v_recovery := jsonb_build_object('ok',false,'error',sqlerrm);
      end;
    end if;

    v_checks := v_checks || jsonb_build_object(v_job.jobname,jsonb_build_object(
      'active',coalesce(v_existing.active,true),
      'last_success',v_last_success,
      'latest_status',v_latest_status,
      'recovery_reason',v_reason,
      'recovery_result',v_recovery
    ));
  end loop;

  v_phase3 := public.ct_phase3_project_status_v3();
  v_pentaroute := public.pentaroute_status_v3();

  select coalesce(jsonb_object_agg(certification_state, cnt), '{}'::jsonb)
  into v_factory
  from (
    select certification_state, count(*)::int as cnt
    from public.ct_factory_adapter_certification_queue
    group by certification_state
  ) f;

  update integration_control.pentaroute_autonomy_runs_v3
  set completed_at=now(), state=v_state, healed_jobs=v_healed, stale_jobs=v_stale,
      checks=v_checks, phase3_snapshot=v_phase3, pentaroute_snapshot=v_pentaroute,
      factory_snapshot=v_factory,
      metadata=metadata || jsonb_build_object(
        'd3_human_governance',true,
        'universal_delete',false,
        'provider_authority_manufacture',false,
        'uncertified_mutations',false
      )
  where run_id=v_run_id;

  return jsonb_build_object(
    'ok',v_state='OPERATIONAL',
    'state',v_state,
    'run_id',v_run_id,
    'healed_jobs',v_healed,
    'stale_jobs',v_stale,
    'checks',v_checks,
    'phase3',v_phase3,
    'pentaroute',v_pentaroute,
    'factory_certification_queue',v_factory,
    'guardrails',jsonb_build_object(
      'max_auto_risk','D2',
      'd3_human_governance',true,
      'universal_delete',false,
      'self_approval',false
    )
  );
exception when others then
  v_err := sqlerrm;
  update integration_control.pentaroute_autonomy_runs_v3
  set completed_at=now(), state='ERROR', error=v_err,
      metadata=metadata || jsonb_build_object('d3_human_governance',true,'universal_delete',false)
  where run_id=v_run_id;
  return jsonb_build_object('ok',false,'state','ERROR','run_id',v_run_id,'error',v_err);
end;
$$;

revoke all on function integration_control.pentaroute_autonomy_cycle_v3() from public, anon, authenticated;
grant execute on function integration_control.pentaroute_autonomy_cycle_v3() to service_role;

create or replace function public.pentaroute_autonomy_status_v3()
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select integration_control.pentaroute_autonomy_status_v3(); $$;

create or replace function public.pentaroute_autonomy_cycle_v3()
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select integration_control.pentaroute_autonomy_cycle_v3(); $$;

revoke all on function public.pentaroute_autonomy_status_v3() from public, anon, authenticated;
revoke all on function public.pentaroute_autonomy_cycle_v3() from public, anon, authenticated;
grant execute on function public.pentaroute_autonomy_status_v3() to service_role;
grant execute on function public.pentaroute_autonomy_cycle_v3() to service_role;
grant usage on schema integration_control to service_role;

select cron.schedule(
  'ct-pentaroute-autonomy-v3',
  '*/5 * * * *',
  'select integration_control.pentaroute_autonomy_cycle_v3();'
);

-- Lock raw PentaRoute / Phase 3 RPCs behind service-role surfaces.
revoke execute on function public.pentaroute_authorize_internal_v3(text) from public, anon, authenticated;
revoke execute on function public.pentaroute_authorize_v3(text,text,text) from public, anon, authenticated;
revoke execute on function public.pentaroute_catalog_v3() from public, anon, authenticated;
revoke execute on function public.pentaroute_record_v3(text,text,text,text,text,integer,boolean,integer,text,boolean,boolean,jsonb) from public, anon, authenticated;
revoke execute on function public.pentaroute_status_v3() from public, anon, authenticated;
revoke execute on function public.ct_phase3_project_status_v3() from public, anon, authenticated;
revoke execute on function public.ct_phase3_self_discovery_tick_v3() from public, anon, authenticated;

grant execute on function public.pentaroute_authorize_internal_v3(text) to service_role;
grant execute on function public.pentaroute_authorize_v3(text,text,text) to service_role;
grant execute on function public.pentaroute_catalog_v3() to service_role;
grant execute on function public.pentaroute_record_v3(text,text,text,text,text,integer,boolean,integer,text,boolean,boolean,jsonb) to service_role;
grant execute on function public.pentaroute_status_v3() to service_role;
grant execute on function public.ct_phase3_project_status_v3() to service_role;
grant execute on function public.ct_phase3_self_discovery_tick_v3() to service_role;

alter view public.pentaroute_human_catalog_v3 set (security_invoker = true);
