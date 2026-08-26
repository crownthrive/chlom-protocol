-- PentaDemocracy™ civic enrollment and ballot eligibility snapshotting.

create or replace function penta_runtime.penta_sync_civic_membership_v1()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  v_key text;
  v_status text;
begin
  if new.subject_type not in ('human','agent') then
    return new;
  end if;

  v_key := 'penta.membership.workforce.' || md5(new.subject_ref);
  v_status := case
    when new.lifecycle_state='active' then 'eligible'
    when new.lifecycle_state in ('paused','suspended') then 'suspended'
    when new.lifecycle_state in ('retired','expired') then 'expired'
    else 'nonvoting'
  end;

  insert into public.penta_governance_memberships(
    membership_key,subject_ref,constituency_key,branch_key,civic_role,voting_status,vote_weight,starts_at,metadata
  ) values (
    v_key,new.subject_ref,'penta.constituency.workforce',null,'elector',v_status,1,now(),
    jsonb_build_object('auto_enrolled',true,'source','penta_workforce_subjects','authority_inherited',false)
  )
  on conflict (membership_key) do update set
    voting_status=excluded.voting_status,
    metadata=public.penta_governance_memberships.metadata||excluded.metadata,
    updated_at=now();

  return new;
end;
$$;

drop trigger if exists trg_penta_sync_civic_membership on public.penta_workforce_subjects;
create trigger trg_penta_sync_civic_membership
after insert or update of subject_type,lifecycle_state
on public.penta_workforce_subjects
for each row execute function penta_runtime.penta_sync_civic_membership_v1();

insert into public.penta_governance_memberships(
  membership_key,subject_ref,constituency_key,branch_key,civic_role,voting_status,vote_weight,starts_at,metadata
)
select
  'penta.membership.workforce.'||md5(s.subject_ref),
  s.subject_ref,
  'penta.constituency.workforce',
  null,
  'elector',
  case when s.lifecycle_state='active' then 'eligible'
       when s.lifecycle_state in ('paused','suspended') then 'suspended'
       when s.lifecycle_state in ('retired','expired') then 'expired'
       else 'nonvoting' end,
  1,
  now(),
  jsonb_build_object('auto_enrolled',true,'source','penta_workforce_subjects','backfill',true,'authority_inherited',false)
from public.penta_workforce_subjects s
where s.subject_type in ('human','agent')
on conflict (membership_key) do update set
  voting_status=excluded.voting_status,
  metadata=public.penta_governance_memberships.metadata||excluded.metadata,
  updated_at=now();

create or replace function penta_runtime.penta_prepare_ballot_eligibility_v1(p_ballot_id uuid)
returns jsonb
language plpgsql
set search_path to 'pg_catalog','public','penta_runtime'
as $$
declare
  b public.penta_ballots%rowtype;
  inserted_count integer;
begin
  select * into b from public.penta_ballots where ballot_id=p_ballot_id for update;
  if not found then raise exception 'ballot not found'; end if;
  if b.state not in ('scheduled','open') then
    raise exception 'ballot eligibility can only be prepared before or during an open ballot';
  end if;

  insert into public.penta_ballot_eligibility(ballot_id,membership_id,eligible,reason,subject_type_snapshot)
  select b.ballot_id,m.membership_id,true,'active constituency membership',s.subject_type
  from public.penta_governance_memberships m
  join public.penta_workforce_subjects s on s.subject_ref=m.subject_ref
  where m.constituency_key=b.constituency_key
    and m.voting_status='eligible'
    and m.starts_at<=now()
    and (m.ends_at is null or m.ends_at>now())
    and s.lifecycle_state='active'
    and s.subject_type in ('human','agent')
  on conflict (ballot_id,membership_id) do update set
    eligible=excluded.eligible,
    reason=excluded.reason,
    subject_type_snapshot=excluded.subject_type_snapshot;

  get diagnostics inserted_count = row_count;
  return jsonb_build_object('ballot_id',p_ballot_id,'eligible_snapshot_rows',inserted_count,'prepared_at',now());
end;
$$;

revoke all on function penta_runtime.penta_prepare_ballot_eligibility_v1(uuid) from public,anon,authenticated;
grant execute on function penta_runtime.penta_prepare_ballot_eligibility_v1(uuid) to service_role;

insert into public.penta_workforce_events(event_type,actor_ref,object_ref,payload)
values('penta_democracy_civic_enrollment_v1_activated','system','penta.democracy',jsonb_build_object(
  'auto_enroll_subject_types',jsonb_build_array('human','agent'),
  'exclude_subject_types',jsonb_build_array('service','governance_body'),
  'vote_weight',1,
  'ballot_eligibility_snapshot_explicit',true,
  'authority_inherited',false
));
