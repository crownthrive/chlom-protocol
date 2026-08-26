-- PentaFederation v1
-- Canonical parent: CrownThrive Federation
-- Runtime: ThriveBase / penta_runtime
-- This migration is additive and fail-closed. It does not grant provider-write,
-- money-movement, rights-grant, child-voting, or D3 authority.

create table if not exists public.penta_federation_system_state (
  system_key text primary key,
  name text not null,
  version text not null,
  status text not null,
  parent_federation text not null default 'CrownThrive Federation',
  canonical_repo_parent text not null default 'ct.repo.crownthrive-support',
  authority_ceiling text not null default 'D2/A2',
  charter jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_federation_bindings (
  binding_key text primary key,
  target_type text not null,
  target_id text not null,
  role text not null,
  mode text not null default 'bounded',
  authority_ceiling text not null default 'D2/A2',
  capability_ceiling jsonb not null default '{}'::jsonb,
  binding_state text not null default 'registered',
  source_ref text,
  metadata jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_federation_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  subject_key text not null,
  trace_id uuid not null default gen_random_uuid(),
  actor_class text not null default 'system',
  payload jsonb not null default '{}'::jsonb,
  evidence_digest_sha256 text,
  created_at timestamptz not null default now()
);

create table if not exists public.penta_federation_proofs (
  id uuid primary key default gen_random_uuid(),
  proof_key text not null unique,
  scope text not null,
  status text not null,
  score numeric,
  checks jsonb not null default '{}'::jsonb,
  digest_sha256 text,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.penta_federation_system_state enable row level security;
alter table public.penta_federation_bindings enable row level security;
alter table public.penta_federation_events enable row level security;
alter table public.penta_federation_proofs enable row level security;

revoke all on table public.penta_federation_system_state from anon, authenticated;
revoke all on table public.penta_federation_bindings from anon, authenticated;
revoke all on table public.penta_federation_events from anon, authenticated;
revoke all on table public.penta_federation_proofs from anon, authenticated;

grant all on table public.penta_federation_system_state to service_role;
grant all on table public.penta_federation_bindings to service_role;
grant all on table public.penta_federation_events to service_role;
grant all on table public.penta_federation_proofs to service_role;

insert into public.penta_federation_system_state(
  system_key,
  name,
  version,
  status,
  parent_federation,
  canonical_repo_parent,
  authority_ceiling,
  charter,
  last_verified_at
) values (
  'ct.penta.federation.v1',
  'PentaFederation',
  '1.0.0',
  'controlled_test',
  'CrownThrive Federation',
  'ct.repo.crownthrive-support',
  'D2/A2',
  jsonb_build_object(
    'role','bounded federation governance and routing facade',
    'canonical_federation_schema','institutional_federation',
    'canonical_transport','repository-federation-bus',
    'no_authority_manufacture',true,
    'd3_human_reserved',true,
    'provider_write_inherited',false,
    'money_movement_inherited',false,
    'rights_grant_inherited',false,
    'fail_closed',true,
    'idempotency_required',true,
    'evidence_required',true
  ),
  now()
) on conflict (system_key) do update set
  name=excluded.name,
  version=excluded.version,
  parent_federation=excluded.parent_federation,
  canonical_repo_parent=excluded.canonical_repo_parent,
  authority_ceiling=excluded.authority_ceiling,
  charter=public.penta_federation_system_state.charter || excluded.charter,
  updated_at=now();

insert into public.penta_federation_bindings(
  binding_key,target_type,target_id,role,mode,authority_ceiling,
  capability_ceiling,binding_state,source_ref,metadata,last_verified_at
) values
(
  'ct.penta.federation.binding.repository-bus','runtime',
  'repository-federation-bus','canonical_repository_transport','bounded_oidc',
  'D2/A2',
  '{"read":true,"write":"federation-ledger-only","provider_write":false,"delete":false,"admin":false}'::jsonb,
  'bound','supabase-edge:repository-federation-bus',
  '{"authentication":"GitHub Actions OIDC","audience":"crownthrive-repository-federation"}'::jsonb,
  now()
),
(
  'ct.penta.federation.binding.institutional-schema','database_schema',
  'institutional_federation','canonical_federation_state','reference_and_rpc',
  'D2/A2','{"read":true,"write":"through-governed-rpc","provider_write":false}'::jsonb,
  'bound','thrivebase:institutional_federation','{"source_of_truth":true}'::jsonb,now()
),
(
  'ct.penta.federation.binding.chlom','governance','ct.system.chlom.runtime',
  'authority_and_policy_preflight','governed','D2/A2',
  '{"read":true,"policy":true,"rights_grant":false}'::jsonb,
  'bound','penta_runtime:layer1','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.pentafabric','fabric','ct.fabric.penta.v1',
  'orchestration_parent','bounded','D2/A2',
  '{"route":true,"queue":true,"activate":false}'::jsonb,
  'bound','penta_runtime:fabrics_v1','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.pentamesh','mesh','ct.mesh.penta.v1',
  'routing_mesh','bounded','D2/A2',
  '{"route":true,"provider_write":false}'::jsonb,
  'bound','penta_runtime:fabrics_v1','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.factory','software_factory','crownthrive-os-v2-factory',
  'build_and_distribution_handoff','candidate_only','D2/A2',
  '{"build":true,"package":true,"deploy":"requires-certified-adapter"}'::jsonb,
  'bound','penta_runtime:layer7','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.dail','evidence','ct.system.dail',
  'append_only_evidence','append_only','D1/A1',
  '{"append":true,"mutate_history":false}'::jsonb,
  'bound','penta_runtime:edge.fabric-to-dail','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.crownlytics','observability','ct.system.crownlytics',
  'least_data_observation','read_only','D1/A1',
  '{"observe":true,"least_data":true}'::jsonb,
  'bound','penta_runtime:edge.fabric-to-crownlytics','{}'::jsonb,now()
),
(
  'ct.penta.federation.binding.crownthrive-io','api_mcp','ct.integration.crownthrive.io.mcp',
  'interoperability_gateway','bounded','D2/A2',
  '{"read":true,"write":"certified-contract-only","provider_write":false}'::jsonb,
  'registered','chlom:registry/integrations.json',
  '{"endpoint_contract_verification_required":true}'::jsonb,null
)
on conflict (binding_key) do update set
  target_type=excluded.target_type,
  target_id=excluded.target_id,
  role=excluded.role,
  mode=excluded.mode,
  authority_ceiling=excluded.authority_ceiling,
  capability_ceiling=excluded.capability_ceiling,
  binding_state=excluded.binding_state,
  source_ref=excluded.source_ref,
  metadata=public.penta_federation_bindings.metadata || excluded.metadata,
  last_verified_at=excluded.last_verified_at,
  updated_at=now();

insert into penta_runtime.agents_v1(
  agent_id,canonical_name,generation,role_slug,fabric_id,institutional_did,
  parent_agent_id,authority_ceiling,decision_ceiling,execution_mode,
  independent_verifier_required,lifecycle_state,metadata
) values (
  'ct.agent.gen61.penta.federation',
  'PentaFederation Governor',
  61,
  'pentafederation-governor',
  'ct.fabric.penta.v1',
  'did:chlom:agent:pentafederation_governor',
  null,
  'A2',
  'D2',
  'candidate_only',
  true,
  'registered',
  jsonb_build_object(
    'generation_family','PentaAgentic',
    'federation_parent','CrownThrive Federation',
    'canonical_transport','repository-federation-bus',
    'authority_manufacture',false
  )
) on conflict (agent_id) do nothing;

update penta_runtime.fabric_layers_v1
set component_ids=array_append(component_ids,'PentaFederation'),
    metadata=metadata || jsonb_build_object('federation_facade','ct.penta.federation.v1'),
    updated_at=now()
where layer_id='ct.penta.layer.4'
  and not ('PentaFederation'=any(component_ids));

insert into penta_runtime.edges_v1(
  edge_id,source_id,target_id,edge_kind,route_state,authority_class,
  redundancy_group,fail_closed,provider_write,money_movement,rights_grant,
  source_ref,metadata
) values
(
  'ct.penta.edge.fabric-to-federation','ct.fabric.penta.v1',
  'ct.agent.gen61.penta.federation','control','controlled_test','D2',
  'federation-control',true,false,false,false,'penta-federation-v1',
  '{"authority_inheritance":false}'::jsonb
),
(
  'ct.penta.edge.chlom-to-federation','ct.system.chlom.runtime',
  'ct.agent.gen61.penta.federation','control','controlled_test','D2',
  'federation-authority',true,false,false,false,'penta-federation-v1',
  '{"policy_preflight":true,"authority_inheritance":false}'::jsonb
),
(
  'ct.penta.edge.federation-to-repository-bus','ct.agent.gen61.penta.federation',
  'ct.system.repository-federation-bus.v1','handoff','controlled_test','D2',
  'federation-transport',true,false,false,false,
  'supabase-edge:repository-federation-bus',
  '{"transport":"github-oidc","provider_write":false}'::jsonb
),
(
  'ct.penta.edge.federation-to-mesh','ct.agent.gen61.penta.federation',
  'ct.mesh.penta.v1','handoff','controlled_test','D1',
  'institutional-routing',true,false,false,false,'penta-federation-v1',
  '{"least_data":true}'::jsonb
),
(
  'ct.penta.edge.federation-to-dail','ct.agent.gen61.penta.federation',
  'ct.system.dail','evidence','controlled_test','D1',
  'evidence',true,false,false,false,'penta-federation-v1',
  '{"append_only":true}'::jsonb
),
(
  'ct.penta.edge.federation-to-crownlytics','ct.agent.gen61.penta.federation',
  'ct.system.crownlytics','data','controlled_test','D1',
  'observation',true,false,false,false,'penta-federation-v1',
  '{"least_data":true}'::jsonb
)
on conflict (edge_id) do nothing;

create or replace function penta_runtime.penta_federation_status_v1()
returns jsonb
language sql
stable
security definer
set search_path to 'pg_catalog','public','institutional_federation','penta_runtime'
as $$
select jsonb_build_object(
  'system',(
    select to_jsonb(s)
    from public.penta_federation_system_state s
    where system_key='ct.penta.federation.v1'
  ),
  'canonical_parent',(
    select jsonb_build_object(
      'repo_id',r.repo_id,
      'repo_full_name',r.repo_full_name,
      'repo_role',r.repo_role,
      'governance_state',r.governance_state,
      'operationally_enabled',r.operationally_enabled,
      'authority_ceiling',r.authority_ceiling,
      'last_heartbeat_at',r.last_heartbeat_at
    )
    from institutional_federation.repository_registry r
    where r.repo_role='canonical_parent'
    order by r.created_at
    limit 1
  ),
  'repositories',jsonb_build_object(
    'total',(select count(*) from institutional_federation.repository_registry),
    'operational',(select count(*) from institutional_federation.repository_registry where operationally_enabled),
    'linked_governed',(select count(*) from institutional_federation.repository_registry where governance_state='linked_governed'),
    'pending_provisioning',(select count(*) from institutional_federation.repository_registry where governance_state='pending_provisioning'),
    'provisioned_unlinked',(select count(*) from institutional_federation.repository_registry where governance_state='provisioned_unlinked'),
    'non_voting_children',(select count(*) from institutional_federation.repository_registry where repo_role='framework_child' and not can_vote)
  ),
  'bindings',jsonb_build_object(
    'total',(select count(*) from public.penta_federation_bindings),
    'core',(select count(*) from public.penta_federation_bindings where binding_key like 'ct.penta.federation.binding.%'),
    'participants',(select count(*) from public.penta_federation_bindings where binding_key not like 'ct.penta.federation.binding.%'),
    'states',(
      select coalesce(jsonb_object_agg(binding_state,state_count),'{}'::jsonb)
      from (
        select binding_state,count(*) state_count
        from public.penta_federation_bindings
        group by binding_state
        order by binding_state
      ) s
    )
  ),
  'transport',jsonb_build_object(
    'edge_function','repository-federation-bus',
    'auth','GitHub Actions OIDC',
    'custom_auth',true,
    'provider_write',false
  ),
  'guardrails',jsonb_build_object(
    'fail_closed',true,
    'd3_human_reserved',true,
    'authority_manufacture',false,
    'provider_write_inherited',false,
    'money_movement_inherited',false,
    'rights_grant_inherited',false
  ),
  'penta_edges',(
    select count(*)
    from penta_runtime.edges_v1
    where edge_id like 'ct.penta.edge.federation-%'
       or edge_id in (
         'ct.penta.edge.fabric-to-federation',
         'ct.penta.edge.chlom-to-federation'
       )
  ),
  'events',(select count(*) from public.penta_federation_events),
  'proofs',(select count(*) from public.penta_federation_proofs)
);
$$;

create or replace function penta_runtime.penta_federation_member_state_v1(
  p_repo_id text
)
returns jsonb
language sql
stable
security definer
set search_path to 'pg_catalog','institutional_federation'
as $$
select coalesce((
  select jsonb_build_object(
    'repo_id',r.repo_id,
    'repo_full_name',r.repo_full_name,
    'repo_role',r.repo_role,
    'parent_repo_id',r.parent_repo_id,
    'framework_id',r.framework_id,
    'governance_state',r.governance_state,
    'operationally_enabled',r.operationally_enabled,
    'authority_ceiling',r.authority_ceiling,
    'can_vote',r.can_vote,
    'last_heartbeat_at',r.last_heartbeat_at,
    'heartbeat_ttl_seconds',r.heartbeat_ttl_seconds,
    'bindings',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'agent_id',b.agent_id,
        'agent_role',b.agent_role,
        'authority_ceiling',b.authority_ceiling,
        'binding_state',b.binding_state,
        'bootstrap',b.bootstrap_enabled,
        'heartbeat',b.heartbeat_enabled,
        'publish',b.publish_enabled,
        'ack',b.ack_enabled,
        'reference',b.reference_enabled,
        'algorithm',b.algorithm_enabled,
        'certify',b.certify_enabled,
        'sync_agents',b.sync_agents_enabled,
        'vote_eligible',b.vote_eligible
      ) order by b.agent_id),'[]'::jsonb)
      from institutional_federation.repository_agent_bindings b
      where b.repo_id=r.repo_id
    )
  )
  from institutional_federation.repository_registry r
  where r.repo_id=p_repo_id
),jsonb_build_object('found',false,'repo_id',p_repo_id));
$$;

create or replace function penta_runtime.penta_federation_route_plan_v1(
  p_repo_id text,
  p_agent_id text,
  p_operation text,
  p_authority_key text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','institutional_federation'
as $$
declare
  r institutional_federation.repository_registry%rowtype;
  b institutional_federation.repository_agent_bindings%rowtype;
  v_capability boolean := false;
  v_precert boolean := false;
  v_runtime_ready boolean := false;
  v_authority_locked boolean := false;
  v_reason text := 'denied';
begin
  select * into r
  from institutional_federation.repository_registry
  where repo_id=p_repo_id;

  if not found then
    return jsonb_build_object(
      'permitted',false,
      'reason','repository_not_registered',
      'repo_id',p_repo_id
    );
  end if;

  select * into b
  from institutional_federation.repository_agent_bindings
  where repo_id=p_repo_id and agent_id=p_agent_id;

  if not found then
    return jsonb_build_object(
      'permitted',false,
      'reason','agent_not_bound',
      'repo_id',p_repo_id,
      'agent_id',p_agent_id
    );
  end if;

  v_precert := r.repo_role='framework_child'
    and r.governance_state='provisioned_unlinked'
    and not r.operationally_enabled
    and coalesce((b.metadata->>'precert_transport_only')::boolean,false);

  v_capability := case p_operation
    when 'bootstrap' then b.bootstrap_enabled
    when 'heartbeat' then b.heartbeat_enabled
    when 'publish' then b.publish_enabled
    when 'pull' then b.publish_enabled
    when 'ack' then b.ack_enabled
    when 'reference' then b.reference_enabled
    when 'algorithm' then b.algorithm_enabled
    when 'certify' then b.certify_enabled
    when 'sync_agents' then b.sync_agents_enabled
    when 'status' then true
    else false
  end;

  v_runtime_ready := case
    when p_operation='bootstrap' then
      r.repo_role<>'canonical_parent'
      and r.governance_state in ('pending_provisioning','provisioned_unlinked')
    when v_precert and p_operation in (
      'heartbeat','publish','pull','ack','reference','status'
    ) then true
    else r.operationally_enabled
  end;

  v_authority_locked := p_authority_key is not null
    and r.repo_role<>'canonical_parent'
    and r.parent_lock_keys ? p_authority_key
    and not (r.override_authority ? p_authority_key);

  if not v_capability then
    v_reason:='capability_not_authorized';
  elsif not v_runtime_ready then
    v_reason:='repository_not_runtime_ready';
  elsif v_authority_locked then
    v_reason:='parent_lock_active';
  else
    v_reason:='bounded_route_permitted';
  end if;

  return jsonb_build_object(
    'permitted',(v_capability and v_runtime_ready and not v_authority_locked),
    'reason',v_reason,
    'repo_id',r.repo_id,
    'repo_role',r.repo_role,
    'governance_state',r.governance_state,
    'operationally_enabled',r.operationally_enabled,
    'agent_id',b.agent_id,
    'binding_state',b.binding_state,
    'authority_ceiling',b.authority_ceiling,
    'operation',p_operation,
    'precert_transport',v_precert,
    'authority_key',p_authority_key,
    'parent_lock_active',v_authority_locked,
    'provider_write',false,
    'money_movement',false,
    'rights_grant',false,
    'activation_authority_inherited',false
  );
end;
$$;

create or replace function penta_runtime.penta_federation_record_event_v1(
  p_event_type text,
  p_subject_key text,
  p_trace_id uuid,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $$
declare
  v_id uuid:=gen_random_uuid();
  v_trace uuid:=coalesce(p_trace_id,gen_random_uuid());
begin
  if p_event_type is null or btrim(p_event_type)=''
     or p_subject_key is null or btrim(p_subject_key)='' then
    raise exception 'event_type_and_subject_required';
  end if;

  insert into public.penta_federation_events(
    id,event_type,subject_key,trace_id,payload
  ) values (
    v_id,p_event_type,p_subject_key,v_trace,coalesce(p_payload,'{}'::jsonb)
  );

  return jsonb_build_object(
    'event_id',v_id,
    'trace_id',v_trace,
    'recorded',true
  );
end;
$$;

grant execute on function penta_runtime.penta_federation_status_v1() to service_role;
grant execute on function penta_runtime.penta_federation_member_state_v1(text) to service_role;
grant execute on function penta_runtime.penta_federation_route_plan_v1(text,text,text,text) to service_role;
grant execute on function penta_runtime.penta_federation_record_event_v1(text,text,uuid,jsonb) to service_role;

-- Fold federation health into the umbrella PentaFabric status response.
create or replace function penta_runtime.status_v1()
returns jsonb
language sql
stable
security definer
set search_path to 'pg_catalog','penta_runtime'
as $$
select jsonb_build_object(
  'fabrics',(
    select coalesce(jsonb_agg(to_jsonb(f) order by fabric_id),'[]'::jsonb)
    from penta_runtime.fabrics_v1 f
  ),
  'layers',(
    select coalesce(jsonb_agg(to_jsonb(l) order by ordinal),'[]'::jsonb)
    from penta_runtime.fabric_layers_v1 l
    where fabric_id='ct.fabric.penta.v1'
  ),
  'generation61_agents',(
    select coalesce(jsonb_agg(jsonb_build_object(
      'agent_id',agent_id,
      'canonical_name',canonical_name,
      'institutional_did',institutional_did,
      'execution_mode',execution_mode,
      'authority_ceiling',authority_ceiling,
      'decision_ceiling',decision_ceiling
    ) order by canonical_name),'[]'::jsonb)
    from penta_runtime.agents_v1
    where generation=61
  ),
  'federation',penta_runtime.penta_federation_status_v1(),
  'open_jobs',(
    select count(*)
    from penta_runtime.jobs_v1
    where state not in ('completed','implemented','failed','expired')
  ),
  'patch_packages',(
    select count(*)
    from penta_runtime.patch_packages_v1
    where state not in ('published','superseded','failed')
  ),
  'latest_window',(
    select to_jsonb(w)
    from penta_runtime.maintenance_windows_v1 w
    order by local_date desc
    limit 1
  ),
  'latest_wave',(
    select to_jsonb(w)
    from penta_runtime.wave_registry_v1 w
    order by created_at desc
    limit 1
  )
);
$$;

grant execute on function penta_runtime.status_v1() to service_role;
