-- Penta Democratic Governance™ v1 guardrails
-- Mirrors penta_three_branch_democratic_governance_guardrails_v1.

create or replace function penta_runtime.penta_validate_ballot_vote_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  b public.penta_ballots%rowtype;
  e public.penta_ballot_eligibility%rowtype;
  m public.penta_governance_memberships%rowtype;
begin
  select * into b from public.penta_ballots where ballot_id=new.ballot_id for update;
  if not found then raise exception 'ballot not found'; end if;
  if b.state <> 'open' or now() < b.opens_at or now() >= b.closes_at then
    raise exception 'ballot is not open';
  end if;

  select * into e from public.penta_ballot_eligibility
  where ballot_id=new.ballot_id and membership_id=new.membership_id and eligible;
  if not found then raise exception 'membership is not eligible for ballot'; end if;

  select * into m from public.penta_governance_memberships
  where membership_id=new.membership_id and voting_status='eligible'
    and starts_at<=now() and (ends_at is null or ends_at>now());
  if not found then raise exception 'governance membership is not currently eligible'; end if;

  if new.choice='recuse' and not new.conflict_disclosed then
    raise exception 'recusal requires conflict disclosure';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_penta_validate_ballot_vote on public.penta_ballot_votes;
create trigger trg_penta_validate_ballot_vote
before insert or update on public.penta_ballot_votes
for each row execute function penta_runtime.penta_validate_ballot_vote_v1();

create or replace function penta_runtime.penta_close_ballot_v1(p_ballot_id uuid)
returns jsonb
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  b public.penta_ballots%rowtype;
  eligible_count integer;
  participation integer;
  yes_count integer;
  no_count integer;
  human_yes integer;
  human_no integer;
  human_participation integer;
  quorum_met boolean;
  approval_met boolean;
  human_met boolean;
  final_result text;
  snapshot jsonb;
begin
  select * into b from public.penta_ballots where ballot_id=p_ballot_id for update;
  if not found then raise exception 'ballot not found'; end if;
  if b.state='cancelled' then raise exception 'cancelled ballot cannot be tallied'; end if;
  if now() < b.closes_at and b.state <> 'closed' then raise exception 'ballot has not reached close time'; end if;

  select count(*) into eligible_count
  from public.penta_ballot_eligibility
  where ballot_id=p_ballot_id and eligible;

  select
    count(*) filter (where v.choice in ('yes','no','abstain')),
    count(*) filter (where v.choice='yes'),
    count(*) filter (where v.choice='no'),
    count(*) filter (where e.subject_type_snapshot='human' and v.choice='yes'),
    count(*) filter (where e.subject_type_snapshot='human' and v.choice='no'),
    count(*) filter (where e.subject_type_snapshot='human' and v.choice in ('yes','no','abstain'))
  into participation,yes_count,no_count,human_yes,human_no,human_participation
  from public.penta_ballot_votes v
  join public.penta_ballot_eligibility e
    on e.ballot_id=v.ballot_id and e.membership_id=v.membership_id
  where v.ballot_id=p_ballot_id;

  quorum_met := eligible_count > 0 and participation::numeric/eligible_count >= b.quorum_ratio;
  approval_met := (yes_count+no_count)>0 and yes_count::numeric/(yes_count+no_count) >= b.approval_ratio;
  human_met := not b.human_ratification_required
    or ((human_yes+human_no)>0 and human_yes::numeric/(human_yes+human_no) >= b.human_approval_ratio);

  final_result := case
    when not quorum_met then 'invalid'
    when yes_count=no_count and yes_count>0 then 'tied'
    when approval_met and human_met then 'passed'
    else 'failed'
  end;

  snapshot := jsonb_build_object(
    'eligible',eligible_count,
    'participation',participation,
    'yes',yes_count,
    'no',no_count,
    'human_participation',human_participation,
    'human_yes',human_yes,
    'human_no',human_no,
    'quorum_met',quorum_met,
    'approval_met',approval_met,
    'human_ratification_met',human_met,
    'result',final_result,
    'closed_at',now()
  );

  update public.penta_ballots
  set state='closed', result=final_result, result_snapshot=snapshot, updated_at=now()
  where ballot_id=p_ballot_id;

  return snapshot;
end;
$$;

create or replace function penta_runtime.penta_executive_action_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  a public.penta_workforce_assignments%rowtype;
  r public.penta_workforce_roles%rowtype;
begin
  select * into a
  from public.penta_workforce_assignments
  where assignment_id=new.issuer_assignment_id and state='active'
    and starts_at<=now() and (ends_at is null or ends_at>now());
  if not found then raise exception 'executive issuer assignment is not active'; end if;

  select * into r from public.penta_workforce_roles where role_key=a.role_key and active;
  if not found then raise exception 'executive issuer role is not active'; end if;

  if r.role_key not in ('penta.role.board','penta.role.director','penta.role.manager') then
    raise exception 'role % is not an executive-chain issuer',r.role_key;
  end if;

  if new.action_type='emergency_action' then
    if new.expires_at is null or new.expires_at > new.effective_at + interval '72 hours' then
      raise exception 'emergency executive action must expire within 72 hours';
    end if;
    new.requires_legislative_review := true;
    new.requires_judicial_review := true;
  end if;

  if new.risk_level in ('D2','D3') then
    new.requires_legislative_review := true;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_executive_action_guard on public.penta_executive_actions;
create trigger trg_penta_executive_action_guard
before insert or update on public.penta_executive_actions
for each row execute function penta_runtime.penta_executive_action_guard_v1();

create or replace function penta_runtime.penta_judicial_panel_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  c public.penta_judicial_cases%rowtype;
  m public.penta_governance_memberships%rowtype;
  judge_subject text;
begin
  select * into c from public.penta_judicial_cases where case_id=new.case_id;
  if not found then raise exception 'judicial case not found'; end if;

  select * into m from public.penta_governance_memberships where membership_id=new.judge_membership_id;
  if not found or m.civic_role <> 'judge' or m.voting_status <> 'eligible' then
    raise exception 'panel member is not an eligible judge';
  end if;

  judge_subject := m.subject_ref;
  if judge_subject is not null and judge_subject in (coalesce(c.appellant_subject_ref,''),coalesce(c.respondent_subject_ref,'')) then
    raise exception 'a party to a case cannot sit as judge';
  end if;

  if new.conflict_declared and not new.recused then
    raise exception 'declared judicial conflict requires recusal';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_judicial_panel_guard on public.penta_judicial_panel_members;
create trigger trg_penta_judicial_panel_guard
before insert or update on public.penta_judicial_panel_members
for each row execute function penta_runtime.penta_judicial_panel_guard_v1();

create or replace function penta_runtime.penta_judicial_decision_guard_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  c public.penta_judicial_cases%rowtype;
  active_judges integer;
  required_judges integer;
begin
  select * into c from public.penta_judicial_cases where case_id=new.case_id;
  if not found then raise exception 'judicial case not found'; end if;

  select count(*) into active_judges
  from public.penta_judicial_panel_members
  where case_id=new.case_id and panel_role in ('chief_judge','judge') and not recused;

  required_judges := case when c.risk_level in ('D2','D3') then 3 else 1 end;
  if active_judges < required_judges then
    raise exception 'insufficient non-recused judicial panel for risk level %',c.risk_level;
  end if;

  if new.disposition in ('reverse','invalidate_internal_action','modify') and new.remedy='{}'::jsonb then
    raise exception 'reversal/modification requires an explicit remedy';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_penta_judicial_decision_guard on public.penta_judicial_decisions;
create trigger trg_penta_judicial_decision_guard
before insert or update on public.penta_judicial_decisions
for each row execute function penta_runtime.penta_judicial_decision_guard_v1();

create or replace function penta_runtime.penta_governance_status_v1()
returns jsonb
language sql
stable
security invoker
set search_path to 'pg_catalog','public','penta_runtime'
as $$
select jsonb_build_object(
  'charter',(select jsonb_build_object('key',charter_key,'name',canonical_name,'version',version,'state',state)
    from public.penta_governance_charters where state='active' order by effective_at desc limit 1),
  'branches',(select jsonb_agg(jsonb_build_object('key',branch_key,'name',canonical_name,'type',branch_type,'state',state) order by branch_type)
    from public.penta_governance_branches where state='active'),
  'active_constituencies',(select count(*) from public.penta_constituencies where state='active'),
  'eligible_memberships',(select count(*) from public.penta_governance_memberships where voting_status='eligible' and starts_at<=now() and (ends_at is null or ends_at>now())),
  'open_sessions',(select count(*) from public.penta_legislative_sessions where state in ('scheduled','open','recessed')),
  'open_ballots',(select count(*) from public.penta_ballots where state='open'),
  'active_executive_actions',(select count(*) from public.penta_executive_actions where state='active'),
  'open_judicial_cases',(select count(*) from public.penta_judicial_cases where state not in ('decided','closed','dismissed')),
  'democratic_guardrails',jsonb_build_object(
    'one_membership_one_vote',true,
    'd2_d3_human_ratification',true,
    'conflict_recusal',true,
    'executive_emergency_ttl_hours',72,
    'judicial_panel_d2_d3_minimum',3,
    'branch_authority_manufacture',false,
    'organizational_not_sovereign_government',true
  )
);
$$;

revoke all on function penta_runtime.penta_close_ballot_v1(uuid) from public,anon,authenticated;
grant execute on function penta_runtime.penta_close_ballot_v1(uuid) to service_role;
revoke all on function penta_runtime.penta_governance_status_v1() from public,anon,authenticated;
grant execute on function penta_runtime.penta_governance_status_v1() to service_role;

insert into public.penta_workforce_events(event_type,actor_ref,object_ref,payload)
values('penta_three_branch_guardrails_v1_activated','system','penta.workforce-os',jsonb_build_object(
  'one_membership_one_vote',true,
  'D2_D3_human_ratification',true,
  'emergency_ttl_hours',72,
  'judicial_panel_D2_D3',3,
  'conflict_recusal',true,
  'separation_of_powers',true
));
