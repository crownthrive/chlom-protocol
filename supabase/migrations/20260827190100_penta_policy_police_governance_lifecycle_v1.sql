-- PentaPolicy / PentaPolice / PentaGovernance lifecycle v1
-- Canonical authority flow: PentaPolicy -> PentaGovernance -> PentaPolice.
-- D2 is the maximum effective class for development/testing/certification.
-- D3 becomes effective only for live authority and requires governance ratification.

create table if not exists public.penta_policy_authority_modes (
  authority_key text primary key,
  subject_ref text not null,
  current_risk_class text not null check (current_risk_class in ('D0','D1','D2','D3')),
  operating_mode text not null check (operating_mode in ('development','testing','certification','canary','live','suspended')),
  live_authority boolean not null default false,
  live_authority_ref text,
  changed_by text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((operating_mode <> 'live' and live_authority=false) or (operating_mode='live' and current_risk_class='D3' and live_authority=true and live_authority_ref is not null))
);

create table if not exists public.penta_policy_proposals (
  proposal_id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version text not null,
  title text not null,
  author_system text not null default 'PentaPolicy',
  target_subject_ref text not null,
  target_pentas jsonb not null default '[]'::jsonb,
  policy_body jsonb not null,
  requested_risk_class text not null check (requested_risk_class in ('D0','D1','D2','D3')),
  effective_risk_class text not null check (effective_risk_class in ('D0','D1','D2','D3')),
  lifecycle_state text not null default 'draft' check (lifecycle_state in ('draft','proposed','testing','pending_ratification','ratified','rejected','enforced','superseded','revoked')),
  governance_required boolean not null default false,
  governance_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  ratified_at timestamptz,
  ratification_ref text,
  supersedes_proposal_id uuid references public.penta_policy_proposals(proposal_id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(policy_key,version)
);

create table if not exists public.penta_policy_ratifications (
  ratification_id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.penta_policy_proposals(proposal_id) on delete restrict,
  governance_layer text not null default 'PentaGovernance',
  decision text not null check (decision in ('ratify','reject','return_for_revision')),
  authority_ref text not null,
  human_ratification boolean not null default true,
  decision_body jsonb not null default '{}'::jsonb,
  decided_at timestamptz not null default now(),
  unique(proposal_id,decision,authority_ref)
);

create table if not exists public.penta_police_enforcement_receipts (
  receipt_id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.penta_policy_proposals(proposal_id) on delete restrict,
  policy_key text not null,
  target_subject_ref text not null,
  target_system text not null,
  enforcement_action text not null,
  enforcement_result text not null check (enforcement_result in ('allow','deny','hold','quarantine','require_ratification')),
  risk_class text not null check (risk_class in ('D0','D1','D2','D3')),
  authority_ref text,
  evidence jsonb not null default '[]'::jsonb,
  correlation_id text not null,
  created_at timestamptz not null default now(),
  unique(correlation_id,policy_key,target_system,enforcement_action)
);

alter table public.penta_policy_authority_modes enable row level security;
alter table public.penta_policy_proposals enable row level security;
alter table public.penta_policy_ratifications enable row level security;
alter table public.penta_police_enforcement_receipts enable row level security;

create or replace function public.penta_policy_effective_risk_v1(p_requested text,p_mode text)
returns text language plpgsql immutable as $$
begin
  if p_requested not in ('D0','D1','D2','D3') then raise exception 'invalid_risk_class'; end if;
  if p_mode in ('development','testing','certification') and p_requested='D3' then return 'D2'; end if;
  return p_requested;
end;$$;

create or replace function public.penta_policy_propose_v1(p_policy_key text,p_version text,p_title text,p_target_subject_ref text,p_target_pentas jsonb,p_policy_body jsonb,p_requested_risk_class text,p_operating_mode text default 'testing',p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_id uuid; v_effective text; v_gov boolean; v_state text;
begin
  v_effective:=public.penta_policy_effective_risk_v1(p_requested_risk_class,p_operating_mode);
  v_gov:=(v_effective='D3');
  v_state:=case when v_gov then 'pending_ratification' when p_operating_mode in ('testing','certification') then 'testing' else 'proposed' end;
  insert into public.penta_policy_proposals(policy_key,version,title,target_subject_ref,target_pentas,policy_body,requested_risk_class,effective_risk_class,lifecycle_state,governance_required,metadata)
  values(p_policy_key,p_version,p_title,p_target_subject_ref,coalesce(p_target_pentas,'[]'::jsonb),p_policy_body,p_requested_risk_class,v_effective,v_state,v_gov,coalesce(p_metadata,'{}'::jsonb))
  on conflict(policy_key,version) do update set title=excluded.title,target_subject_ref=excluded.target_subject_ref,target_pentas=excluded.target_pentas,policy_body=excluded.policy_body,requested_risk_class=excluded.requested_risk_class,effective_risk_class=excluded.effective_risk_class,lifecycle_state=excluded.lifecycle_state,governance_required=excluded.governance_required,metadata=excluded.metadata,updated_at=now()
  returning proposal_id into v_id;
  return v_id;
end;$$;

create or replace function public.penta_governance_ratify_policy_v1(p_proposal_id uuid,p_decision text,p_authority_ref text,p_decision_body jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare v public.penta_policy_proposals%rowtype;
begin
  select * into v from public.penta_policy_proposals where proposal_id=p_proposal_id for update;
  if not found then raise exception 'policy_proposal_not_found'; end if;
  if v.effective_risk_class <> 'D3' or v.governance_required=false then raise exception 'ratification_not_required_for_non_d3'; end if;
  insert into public.penta_policy_ratifications(proposal_id,decision,authority_ref,human_ratification,decision_body) values(p_proposal_id,p_decision,p_authority_ref,true,coalesce(p_decision_body,'{}'::jsonb));
  update public.penta_policy_proposals set lifecycle_state=case p_decision when 'ratify' then 'ratified' when 'reject' then 'rejected' else 'proposed' end,ratified_at=case when p_decision='ratify' then now() else ratified_at end,ratification_ref=case when p_decision='ratify' then p_authority_ref else ratification_ref end,updated_at=now() where proposal_id=p_proposal_id;
  return jsonb_build_object('proposal_id',p_proposal_id,'decision',p_decision,'state',(select lifecycle_state from public.penta_policy_proposals where proposal_id=p_proposal_id));
end;$$;

create or replace function public.penta_police_enforce_v1(p_policy_key text,p_target_subject_ref text,p_target_system text,p_enforcement_action text,p_correlation_id text,p_evidence jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare v public.penta_policy_proposals%rowtype; v_result text; v_auth text;
begin
  select * into v from public.penta_policy_proposals where policy_key=p_policy_key and target_subject_ref=p_target_subject_ref and lifecycle_state in ('testing','ratified','enforced') order by created_at desc limit 1;
  if not found then return jsonb_build_object('policy_key',p_policy_key,'target_subject_ref',p_target_subject_ref,'target_system',p_target_system,'result','deny','reason','no_enforceable_policy'); end if;
  if v.effective_risk_class='D3' and v.lifecycle_state not in ('ratified','enforced') then v_result:='require_ratification'; else v_result:='allow'; end if;
  v_auth:=case when v.effective_risk_class='D3' then v.ratification_ref else 'PentaPolicy:D2-bounded-authority' end;
  insert into public.penta_police_enforcement_receipts(proposal_id,policy_key,target_subject_ref,target_system,enforcement_action,enforcement_result,risk_class,authority_ref,evidence,correlation_id)
  values(v.proposal_id,p_policy_key,p_target_subject_ref,p_target_system,p_enforcement_action,v_result,v.effective_risk_class,v_auth,coalesce(p_evidence,'[]'::jsonb),p_correlation_id)
  on conflict(correlation_id,policy_key,target_system,enforcement_action) do update set evidence=excluded.evidence;
  return jsonb_build_object('policy_key',p_policy_key,'target_subject_ref',p_target_subject_ref,'target_system',p_target_system,'result',v_result,'risk_class',v.effective_risk_class,'authority_ref',v_auth);
end;$$;

revoke all on function public.penta_policy_propose_v1(text,text,text,text,jsonb,jsonb,text,text,jsonb) from public;
revoke all on function public.penta_governance_ratify_policy_v1(uuid,text,text,jsonb) from public;
revoke all on function public.penta_police_enforce_v1(text,text,text,text,text,jsonb) from public;
grant execute on function public.penta_policy_propose_v1(text,text,text,text,jsonb,jsonb,text,text,jsonb) to service_role;
grant execute on function public.penta_governance_ratify_policy_v1(uuid,text,text,jsonb) to service_role;
grant execute on function public.penta_police_enforce_v1(text,text,text,text,text,jsonb) to service_role;
