-- Assert and preserve Penta family marks. This is a brand registry, not a federal registration record.
insert into public.penta_mark_registry(
  mark_key,canonical_name,display_mark,owner_name,mark_family,symbol,registration_status,jurisdiction,use_status,disclaimer,metadata
)
select
  'mark.' || regexp_replace(lower(canonical_name),'[^a-z0-9]+','-','g'),
  canonical_name,
  canonical_name || '™',
  'CrownThrive, LLC',
  'Penta',
  'TM',
  'unregistered_asserted',
  'US',
  'claimed',
  canonical_name || '™ is a claimed mark of CrownThrive, LLC. The ™ symbol denotes a claimed mark and does not state federal registration. The ® symbol may be used only after registration is independently verified.',
  jsonb_build_object('source','penta_system_registry','preserve_penta_name',true)
from public.penta_system_registry
where canonical_name ilike 'Penta%'
on conflict (mark_key) do update set
  canonical_name=excluded.canonical_name,
  display_mark=excluded.display_mark,
  owner_name=excluded.owner_name,
  symbol=case when public.penta_mark_registry.registration_status='registered' then public.penta_mark_registry.symbol else 'TM' end,
  disclaimer=excluded.disclaimer,
  metadata=public.penta_mark_registry.metadata || excluded.metadata,
  updated_at=now();

-- Reconcile existing leased PentaSuite agents into the workforce directory without changing their lease authority.
insert into public.penta_workforce_subjects(subject_ref,subject_type,display_name,source_system,source_ref,lifecycle_state,metadata)
select
  'agent:' || l.agent_key,
  'agent',
  l.agent_key,
  'PentaSuite',
  l.id::text,
  case when l.state in ('active','conditional') and (l.expires_at is null or l.expires_at > now()) then 'active'
       when l.state in ('expired','revoked','rolled_back') then 'expired'
       else 'paused' end,
  jsonb_build_object(
    'lease_id',l.id,
    'lease_state',l.state,
    'lease_generation',l.lease_generation,
    'ttl_seconds',l.ttl_seconds,
    'authority_inherited',false
  )
from public.pentasuite_agent_leases l
on conflict (subject_ref) do update set
  source_ref=excluded.source_ref,
  lifecycle_state=excluded.lifecycle_state,
  metadata=public.penta_workforce_subjects.metadata || excluded.metadata,
  updated_at=now();

insert into public.penta_workforce_assignments(
  assignment_key,subject_ref,role_key,unit_key,scope,starts_at,ends_at,state,source_ref,metadata
)
select
  'penta.assignment.agent.' || regexp_replace(lower(l.agent_key),'[^a-z0-9]+','-','g'),
  'agent:' || l.agent_key,
  'penta.role.worker',
  null,
  l.scope_envelope,
  coalesce(l.starts_at,l.created_at),
  l.expires_at,
  case when l.state in ('active','conditional') and (l.expires_at is null or l.expires_at > now()) then 'active'
       when l.state in ('expired','revoked','rolled_back') then 'expired'
       else 'paused' end,
  'pentasuite-lease:' || l.id::text,
  jsonb_build_object(
    'lease_id',l.id,
    'lease_generation',l.lease_generation,
    'manager_unassigned',true,
    'authority_inherited',false
  )
from public.pentasuite_agent_leases l
on conflict (assignment_key) do update set
  scope=excluded.scope,
  starts_at=excluded.starts_at,
  ends_at=excluded.ends_at,
  state=excluded.state,
  source_ref=excluded.source_ref,
  metadata=public.penta_workforce_assignments.metadata || excluded.metadata,
  updated_at=now();

create index if not exists penta_workforce_assignments_subject_state_idx
  on public.penta_workforce_assignments(subject_ref,state);
create index if not exists penta_workforce_assignments_role_state_idx
  on public.penta_workforce_assignments(role_key,state);
create index if not exists penta_notes_subject_state_idx
  on public.penta_notes(subject_ref,state);
create index if not exists penta_triage_state_severity_idx
  on public.penta_triage_cases(state,severity);
create index if not exists penta_health_subject_created_idx
  on public.penta_health_snapshots(subject_ref,created_at desc);
create index if not exists penta_cost_events_budget_created_idx
  on public.penta_cost_events(budget_id,created_at desc);
create index if not exists penta_pay_beneficiary_state_idx
  on public.penta_pay_entries(beneficiary_subject_ref,state);
create index if not exists penta_events_created_idx
  on public.penta_workforce_events(created_at desc);

insert into public.penta_workforce_events(event_type,actor_ref,object_ref,payload)
values (
  'penta_workforce_os_v1_institutionalized',
  'founder-directive:2026-08-26',
  'penta.workforce-os',
  jsonb_build_object(
    'version','1.0.0',
    'phase','3',
    'hierarchy','PentaBoard>PentaDirectors>PentaManagers>PentaCohorts>workers',
    'guardrails',jsonb_build_array('fail_closed','no_self_approval','cost_caps','appeals','no_money_movement','no_medical_decisioning'),
    'marks','TM_ASSERTED'
  )
);
