do $$
declare t text;
begin
  foreach t in array array[
    'penta_workforce_system_state','penta_workforce_roles','penta_workforce_subjects',
    'penta_workforce_units','penta_workforce_assignments','penta_governance_instruments',
    'penta_cohorts','penta_cohort_members','penta_notes','penta_note_votes',
    'penta_triage_cases','penta_health_snapshots','penta_hr_cases',
    'penta_benefit_entitlements','penta_pay_entries','penta_cost_budgets',
    'penta_cost_events','penta_accelerator_records','penta_ramifications',
    'penta_mark_registry','penta_workforce_events'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
  end loop;
end $$;

create or replace function penta_runtime.penta_workforce_validate_instrument_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  v_role public.penta_workforce_roles%rowtype;
  v_assignment public.penta_workforce_assignments%rowtype;
  v_allowed boolean := false;
begin
  select * into v_assignment
  from public.penta_workforce_assignments
  where assignment_id = new.issuer_assignment_id
    and state = 'active'
    and starts_at <= now()
    and (ends_at is null or ends_at > now());

  if not found then
    raise exception 'issuer assignment is not active';
  end if;

  select * into v_role
  from public.penta_workforce_roles
  where role_key = v_assignment.role_key and active;

  if not found then
    raise exception 'issuer role is not active';
  end if;

  v_allowed := case
    when new.instrument_kind = 'directive' then v_role.role_key = 'penta.role.board'
    when new.instrument_kind in ('policy','sop','sla') then v_role.role_key = 'penta.role.director'
    when new.instrument_kind in ('contract','task_order') then v_role.role_key = 'penta.role.manager'
    when new.instrument_kind in ('legal_hold','legal_advisory') then v_role.role_key = 'penta.role.legal'
    else false
  end;

  if not v_allowed then
    raise exception 'role % may not issue %', v_role.role_key, new.instrument_kind;
  end if;

  if new.target_max_rank is not null
     and new.instrument_kind not in ('legal_hold','legal_advisory')
     and new.target_max_rank >= v_role.authority_rank then
    raise exception 'instrument may only bind roles below issuer rank';
  end if;

  if new.instrument_kind in ('contract','task_order')
     and new.target_subject_ref is null
     and new.target_unit_key is null then
    raise exception 'manager contract/task order requires a target';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_validate_instrument on public.penta_governance_instruments;
create trigger trg_penta_validate_instrument
before insert or update of instrument_kind,issuer_assignment_id,target_max_rank,target_subject_ref,target_unit_key
on public.penta_governance_instruments
for each row execute function penta_runtime.penta_workforce_validate_instrument_v1();

create or replace function penta_runtime.penta_cost_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  b public.penta_cost_budgets%rowtype;
  v_committed bigint;
  v_spent bigint;
begin
  select * into b
  from public.penta_cost_budgets
  where budget_id = new.budget_id
  for update;

  if not found or b.state <> 'active' then
    raise exception 'budget is not active';
  end if;

  v_committed := b.committed_minor;
  v_spent := b.spent_minor;

  if new.event_kind = 'commit' then
    v_committed := v_committed + new.amount_minor;
  elsif new.event_kind = 'release' then
    if new.amount_minor > v_committed then
      raise exception 'release exceeds committed amount';
    end if;
    v_committed := v_committed - new.amount_minor;
  elsif new.event_kind = 'spend' then
    v_spent := v_spent + new.amount_minor;
  elsif new.event_kind = 'refund' then
    if new.amount_minor > v_spent then
      raise exception 'refund exceeds spent amount';
    end if;
    v_spent := v_spent - new.amount_minor;
  end if;

  if (v_committed + v_spent) > b.hard_limit_minor then
    raise exception 'PentaCost hard limit exceeded';
  end if;

  update public.penta_cost_budgets
  set committed_minor = v_committed,
      spent_minor = v_spent,
      state = case when v_spent >= hard_limit_minor then 'exhausted' else state end,
      updated_at = now()
  where budget_id = b.budget_id;

  return new;
end;
$$;

drop trigger if exists trg_penta_cost_guard on public.penta_cost_events;
create trigger trg_penta_cost_guard
before insert on public.penta_cost_events
for each row execute function penta_runtime.penta_cost_guard_v1();

create or replace function penta_runtime.penta_pay_self_approval_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  v_approver_subject text;
begin
  if new.approved_by_assignment_id is not null then
    select subject_ref into v_approver_subject
    from public.penta_workforce_assignments
    where assignment_id = new.approved_by_assignment_id and state='active';

    if v_approver_subject = new.beneficiary_subject_ref then
      raise exception 'PentaPay self-approval is prohibited';
    end if;
  end if;

  if new.state = 'paid_external' and new.external_receipt_ref is null then
    raise exception 'external payment receipt required';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_pay_self_approval_guard on public.penta_pay_entries;
create trigger trg_penta_pay_self_approval_guard
before insert or update on public.penta_pay_entries
for each row execute function penta_runtime.penta_pay_self_approval_guard_v1();

create or replace function penta_runtime.penta_ramification_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
begin
  if new.action_type not in ('recognition','accelerator_nomination')
     and new.authority_instrument_id is null then
    raise exception 'punitive/restrictive ramification requires an authority instrument';
  end if;

  if new.action_type in ('restriction','contract_review','cost_hold','pay_hold')
     and not new.appeal_available then
    raise exception 'restrictive ramification must preserve appeal availability';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_ramification_guard on public.penta_ramifications;
create trigger trg_penta_ramification_guard
before insert or update on public.penta_ramifications
for each row execute function penta_runtime.penta_ramification_guard_v1();

create or replace function penta_runtime.penta_workforce_status_v1()
returns jsonb
language sql
stable
security invoker
set search_path to 'pg_catalog','public','penta_runtime'
as $$
select jsonb_build_object(
  'system',(select to_jsonb(s) from public.penta_workforce_system_state s where system_key='penta.workforce-os'),
  'roles',(select count(*) from public.penta_workforce_roles where active),
  'subjects',(select count(*) from public.penta_workforce_subjects where lifecycle_state='active'),
  'assignments',(select count(*) from public.penta_workforce_assignments where state='active'),
  'cohorts',(select count(*) from public.penta_cohorts where state in ('forming','active')),
  'open_notes',(select count(*) from public.penta_notes where state in ('open','under_review')),
  'open_triage',(select count(*) from public.penta_triage_cases where state not in ('resolved','closed')),
  'active_budgets',(select count(*) from public.penta_cost_budgets where state='active'),
  'pay_pending',(select count(*) from public.penta_pay_entries where state in ('proposed','approved','eligible','held')),
  'guardrails',jsonb_build_object(
    'authority_manufacture',false,
    'money_movement',false,
    'medical_decisioning',false,
    'vote_is_punishment_authority',false,
    'self_approval',false,
    'appeals_required_for_restrictions',true
  )
);
$$;

create or replace function penta_runtime.penta_mark_notice_v1(p_mark text)
returns jsonb
language sql
stable
security invoker
set search_path to 'pg_catalog','public','penta_runtime'
as $$
select coalesce(
  (select jsonb_build_object(
    'canonical_name',canonical_name,
    'display_mark',display_mark,
    'owner',owner_name,
    'registration_status',registration_status,
    'symbol',symbol,
    'disclaimer',disclaimer
  )
  from public.penta_mark_registry
  where canonical_name = p_mark or display_mark = p_mark
  limit 1),
  jsonb_build_object('found',false,'query',p_mark)
);
$$;

revoke all on function penta_runtime.penta_workforce_status_v1() from public, anon, authenticated;
grant execute on function penta_runtime.penta_workforce_status_v1() to service_role;
revoke all on function penta_runtime.penta_mark_notice_v1(text) from public, anon, authenticated;
grant execute on function penta_runtime.penta_mark_notice_v1(text) to service_role;
