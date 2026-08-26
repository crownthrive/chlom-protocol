-- Penta Democratic Governance™ v1 core
-- Mirrors the production provider migration penta_three_branch_democratic_governance_core_v1.
-- Internal organizational governance only; not sovereign/state authority.

create table if not exists public.penta_governance_charters (
  charter_key text primary key, canonical_name text not null, version text not null, scope text not null,
  principles jsonb not null default '[]'::jsonb, reserved_powers jsonb not null default '{}'::jsonb,
  democratic_rules jsonb not null default '{}'::jsonb,
  amendment_approval_threshold numeric not null default 0.6667 check (amendment_approval_threshold > 0.5 and amendment_approval_threshold <= 1),
  human_ratification_required boolean not null default true,
  state text not null default 'active' check (state in ('draft','active','superseded','retired')),
  effective_at timestamptz not null default now(), supersedes_charter_key text references public.penta_governance_charters(charter_key),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.penta_governance_branches (
  branch_key text primary key, canonical_name text not null,
  branch_type text not null check (branch_type in ('executive','legislative','judicial')),
  charter_key text not null references public.penta_governance_charters(charter_key),
  mandate text not null, powers jsonb not null default '[]'::jsonb, checks_on jsonb not null default '[]'::jsonb,
  checked_by jsonb not null default '[]'::jsonb, independence_rules jsonb not null default '{}'::jsonb,
  ordinary_chain_binding jsonb not null default '{}'::jsonb,
  state text not null default 'active' check (state in ('forming','active','paused','retired')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.penta_constituencies (
  constituency_key text primary key, canonical_name text not null, scope text not null,
  representation_mode text not null default 'hybrid' check (representation_mode in ('direct','representative','hybrid')),
  eligibility_rules jsonb not null default '{}'::jsonb,
  default_quorum_ratio numeric not null default 0.5 check (default_quorum_ratio > 0 and default_quorum_ratio <= 1),
  default_approval_ratio numeric not null default 0.5 check (default_approval_ratio > 0 and default_approval_ratio <= 1),
  human_floor_ratio numeric not null default 0.5 check (human_floor_ratio >= 0 and human_floor_ratio <= 1),
  state text not null default 'active' check (state in ('forming','active','paused','retired')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.penta_governance_memberships (
  membership_id uuid primary key default gen_random_uuid(), membership_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  constituency_key text not null references public.penta_constituencies(constituency_key),
  branch_key text references public.penta_governance_branches(branch_key),
  civic_role text not null check (civic_role in ('elector','representative','executive','judge','clerk','observer')),
  voting_status text not null default 'eligible' check (voting_status in ('eligible','nonvoting','suspended','expired')),
  vote_weight numeric not null default 1 check (vote_weight = 1), starts_at timestamptz not null default now(), ends_at timestamptz,
  conflict_profile jsonb not null default '{}'::jsonb, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check (ends_at is null or ends_at > starts_at)
);
create unique index if not exists penta_governance_memberships_unique_active_scope
  on public.penta_governance_memberships(subject_ref,constituency_key,coalesce(branch_key,''),civic_role)
  where voting_status <> 'expired';

create table if not exists public.penta_vote_delegations (
  delegation_id uuid primary key default gen_random_uuid(),
  delegator_membership_id uuid not null references public.penta_governance_memberships(membership_id),
  delegate_membership_id uuid not null references public.penta_governance_memberships(membership_id),
  constituency_key text not null references public.penta_constituencies(constituency_key),
  topic_scope jsonb not null default '{}'::jsonb, starts_at timestamptz not null default now(), ends_at timestamptz,
  revocable boolean not null default true, state text not null default 'active' check (state in ('active','revoked','expired')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (delegator_membership_id <> delegate_membership_id), check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.penta_legislative_sessions (
  session_id uuid primary key default gen_random_uuid(), session_key text not null unique, canonical_name text not null,
  constituency_key text not null references public.penta_constituencies(constituency_key),
  branch_key text not null references public.penta_governance_branches(branch_key),
  convened_by_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  starts_at timestamptz not null default now(), ends_at timestamptz, agenda jsonb not null default '[]'::jsonb,
  state text not null default 'open' check (state in ('scheduled','open','recessed','adjourned','closed')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.penta_legislative_items (
  item_id uuid primary key default gen_random_uuid(), item_key text not null unique,
  session_id uuid references public.penta_legislative_sessions(session_id), source_note_id uuid references public.penta_notes(note_id),
  item_type text not null check (item_type in ('initiative','act','policy_framework','budget','rule','charter_amendment','resolution','appointment_confirmation','override')),
  title text not null, sponsor_membership_id uuid references public.penta_governance_memberships(membership_id), body jsonb not null default '{}'::jsonb,
  risk_level text not null default 'D1' check (risk_level in ('D0','D1','D2','D3')), public_reason text not null,
  status text not null default 'introduced' check (status in ('draft','introduced','committee','debate','ballot','passed','failed','vetoed','overridden','enacted','withdrawn','expired')),
  enacted_instrument_id uuid references public.penta_governance_instruments(instrument_id), effective_at timestamptz, expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (expires_at is null or effective_at is null or expires_at > effective_at)
);

create table if not exists public.penta_legislative_amendments (
  amendment_id uuid primary key default gen_random_uuid(), amendment_key text not null unique,
  item_id uuid not null references public.penta_legislative_items(item_id) on delete cascade,
  proposer_membership_id uuid references public.penta_governance_memberships(membership_id), patch jsonb not null, rationale text not null,
  status text not null default 'proposed' check (status in ('proposed','accepted','rejected','withdrawn')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.penta_ballots (
  ballot_id uuid primary key default gen_random_uuid(), ballot_key text not null unique,
  constituency_key text not null references public.penta_constituencies(constituency_key),
  subject_type text not null check (subject_type in ('legislative_item','initiative','appointment','override','confidence','referendum','charter_amendment')),
  subject_ref text not null, title text not null, risk_level text not null default 'D1' check (risk_level in ('D0','D1','D2','D3')),
  quorum_ratio numeric not null check (quorum_ratio > 0 and quorum_ratio <= 1), approval_ratio numeric not null check (approval_ratio > 0 and approval_ratio <= 1),
  human_ratification_required boolean not null default false,
  human_approval_ratio numeric not null default 0.5 check (human_approval_ratio > 0 and human_approval_ratio <= 1),
  opens_at timestamptz not null, closes_at timestamptz not null,
  state text not null default 'scheduled' check (state in ('scheduled','open','closed','cancelled')),
  result text not null default 'pending' check (result in ('pending','passed','failed','tied','invalid')),
  result_snapshot jsonb not null default '{}'::jsonb, secret_ballot boolean not null default false, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (closes_at > opens_at), check (risk_level not in ('D2','D3') or human_ratification_required)
);

create table if not exists public.penta_ballot_eligibility (
  ballot_id uuid not null references public.penta_ballots(ballot_id) on delete cascade,
  membership_id uuid not null references public.penta_governance_memberships(membership_id), eligible boolean not null default true,
  reason text, subject_type_snapshot text not null check (subject_type_snapshot in ('human','agent','service','governance_body')),
  created_at timestamptz not null default now(), primary key (ballot_id,membership_id)
);

create table if not exists public.penta_ballot_votes (
  ballot_id uuid not null references public.penta_ballots(ballot_id) on delete cascade,
  membership_id uuid not null references public.penta_governance_memberships(membership_id),
  choice text not null check (choice in ('yes','no','abstain','recuse')),
  delegated_from_membership_id uuid references public.penta_governance_memberships(membership_id), rationale text,
  conflict_disclosed boolean not null default false, cast_at timestamptz not null default now(), metadata jsonb not null default '{}'::jsonb,
  primary key (ballot_id,membership_id)
);

create table if not exists public.penta_executive_actions (
  action_id uuid primary key default gen_random_uuid(), action_key text not null unique,
  action_type text not null check (action_type in ('implementation_order','administrative_rule','veto','appointment','emergency_action','budget_execution','remand_response')),
  title text not null, issuer_assignment_id uuid not null references public.penta_workforce_assignments(assignment_id),
  source_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  legislative_item_id uuid references public.penta_legislative_items(item_id), authority_ref text not null,
  body jsonb not null default '{}'::jsonb, risk_level text not null default 'D1' check (risk_level in ('D0','D1','D2','D3')),
  requires_legislative_review boolean not null default false, requires_judicial_review boolean not null default false,
  state text not null default 'active' check (state in ('draft','active','stayed','superseded','expired','revoked','completed')),
  effective_at timestamptz not null default now(), expires_at timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (expires_at is null or expires_at > effective_at), check (action_type <> 'veto' or legislative_item_id is not null),
  check (action_type <> 'emergency_action' or (expires_at is not null and expires_at <= effective_at + interval '72 hours'))
);

create table if not exists public.penta_appointments (
  appointment_id uuid primary key default gen_random_uuid(), appointment_key text not null unique,
  nominee_subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  target_branch_key text references public.penta_governance_branches(branch_key), target_role text not null,
  nominated_by_action_id uuid references public.penta_executive_actions(action_id), confirmation_item_id uuid references public.penta_legislative_items(item_id),
  term_starts_at timestamptz, term_ends_at timestamptz,
  status text not null default 'nominated' check (status in ('nominated','confirmed','rejected','active','expired','removed','resigned')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (term_ends_at is null or term_starts_at is null or term_ends_at > term_starts_at)
);

create table if not exists public.penta_judicial_cases (
  case_id uuid primary key default gen_random_uuid(), case_key text not null unique,
  case_type text not null check (case_type in ('appeal','policy_review','authority_dispute','election_challenge','due_process','contract_dispute','disciplinary_review','charter_review','executive_review')),
  title text not null, appellant_subject_ref text references public.penta_workforce_subjects(subject_ref), respondent_subject_ref text references public.penta_workforce_subjects(subject_ref),
  challenged_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  challenged_executive_action_id uuid references public.penta_executive_actions(action_id), challenged_legislative_item_id uuid references public.penta_legislative_items(item_id),
  source_triage_case_id uuid references public.penta_triage_cases(case_id), risk_level text not null default 'D1' check (risk_level in ('D0','D1','D2','D3')),
  petition text not null, evidence_refs jsonb not null default '[]'::jsonb,
  state text not null default 'filed' check (state in ('filed','screening','accepted','paneling','hearing','deliberating','decided','appealed','closed','dismissed')),
  filed_at timestamptz not null default now(), decided_at timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (appellant_subject_ref is null or respondent_subject_ref is null or appellant_subject_ref <> respondent_subject_ref)
);

create table if not exists public.penta_judicial_panel_members (
  case_id uuid not null references public.penta_judicial_cases(case_id) on delete cascade,
  judge_membership_id uuid not null references public.penta_governance_memberships(membership_id),
  panel_role text not null default 'judge' check (panel_role in ('chief_judge','judge','alternate')),
  conflict_declared boolean not null default false, recused boolean not null default false, recusal_reason text,
  joined_at timestamptz not null default now(), primary key (case_id,judge_membership_id)
);

create table if not exists public.penta_judicial_decisions (
  decision_id uuid primary key default gen_random_uuid(), decision_key text not null unique,
  case_id uuid not null references public.penta_judicial_cases(case_id),
  disposition text not null check (disposition in ('affirm','reverse','remand','stay','dismiss','interpret','invalidate_internal_action','modify')),
  holding text not null, reasoning text not null, remedy jsonb not null default '{}'::jsonb,
  precedent_scope text not null default 'persuasive' check (precedent_scope in ('case_only','persuasive','binding_internal')),
  effective_at timestamptz not null default now(), appeal_deadline timestamptz,
  state text not null default 'issued' check (state in ('draft','issued','stayed','superseded','reversed')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (appeal_deadline is null or appeal_deadline > effective_at)
);

create table if not exists public.penta_checks_balances_events (
  event_id uuid primary key default gen_random_uuid(), event_key text not null unique,
  check_type text not null check (check_type in ('veto','override','judicial_stay','judicial_review','legislative_review','confirmation','no_confidence','remand','charter_challenge','emergency_review')),
  initiated_by_branch_key text references public.penta_governance_branches(branch_key), target_branch_key text references public.penta_governance_branches(branch_key),
  source_ref text not null, authority_ref text not null,
  outcome text not null default 'pending' check (outcome in ('pending','sustained','overridden','affirmed','reversed','remanded','expired','dismissed')),
  evidence_refs jsonb not null default '[]'::jsonb, decided_ref text, created_at timestamptz not null default now(), resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

do $$
declare t text;
begin
  foreach t in array array[
    'penta_governance_charters','penta_governance_branches','penta_constituencies','penta_governance_memberships',
    'penta_vote_delegations','penta_legislative_sessions','penta_legislative_items','penta_legislative_amendments',
    'penta_ballots','penta_ballot_eligibility','penta_ballot_votes','penta_executive_actions','penta_appointments',
    'penta_judicial_cases','penta_judicial_panel_members','penta_judicial_decisions','penta_checks_balances_events'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on table public.%I from anon, authenticated',t);
    execute format('grant all on table public.%I to service_role',t);
  end loop;
end $$;

insert into public.penta_governance_charters(charter_key,canonical_name,version,scope,principles,reserved_powers,democratic_rules,amendment_approval_threshold,human_ratification_required,state,metadata)
values('penta.charter.democratic-governance.v1','Penta Democratic Governance Charter™','1.0.0','CrownThrive internal Penta governance',
'["separation_of_powers","democratic_participation","due_process","checks_and_balances","subsidiarity","evidence","appeal","recusal","transparency_by_scope","no_authority_manufacture"]'::jsonb,
'{"founder_and_board_reserved_authority":"preserved where explicitly established","CHLOM":"higher-order authority envelope","provider_rights":"never manufactured","legal_rights":"never manufactured"}'::jsonb,
'{"one_membership_one_vote":true,"direct_and_representative_modes":true,"initiatives":true,"referenda":true,"delegation":true,"quorum_required":true,"conflict_disclosure":true,"recusal":true,"D2_D3_human_ratification":true,"judicial_appeal":true,"veto_override":true,"emergency_review":true}'::jsonb,
0.6667,true,'active','{"institutional":"internal","sovereign":false,"phase":"3"}'::jsonb)
on conflict (charter_key) do update set canonical_name=excluded.canonical_name,version=excluded.version,scope=excluded.scope,principles=excluded.principles,reserved_powers=excluded.reserved_powers,democratic_rules=excluded.democratic_rules,amendment_approval_threshold=excluded.amendment_approval_threshold,human_ratification_required=excluded.human_ratification_required,state='active',metadata=public.penta_governance_charters.metadata||excluded.metadata,updated_at=now();

insert into public.penta_governance_branches(branch_key,canonical_name,branch_type,charter_key,mandate,powers,checks_on,checked_by,independence_rules,ordinary_chain_binding,state,metadata) values
('penta.branch.executive','PentaExecutive™','executive','penta.charter.democratic-governance.v1','Execute valid directives, enacted internal governance, budgets, appointments, operations, and remands through the existing Board-Director-Manager administrative chain.','["implementation","administration","bounded_veto","appointments","budget_execution","time_limited_emergency_action"]'::jsonb,'["legislative_implementation","operational_execution"]'::jsonb,'["legislative_review","override","judicial_review","judicial_stay","board_reserved_authority","CHLOM"]'::jsonb,'{"cannot_legislate_unilaterally":true,"cannot_finally_adjudicate_own_disputes":true,"emergency_actions_expire_within_hours":72,"D2_D3_requires_review":true}'::jsonb,'{"uses_existing_roles":["PentaBoard","PentaDirectors","PentaManagers"],"creates_no_new_supervisory_rank":true}'::jsonb,'active','{"mark":"TM"}'::jsonb),
('penta.branch.legislative','PentaLegislative™','legislative','penta.charter.democratic-governance.v1','Represent affected constituencies; introduce, deliberate, amend, vote, enact, review, and override internal governance measures within delegated authority.','["initiative","deliberation","amendment","internal_acts","policy_frameworks","budget_authorization","confirmation","referendum","override"]'::jsonb,'["executive_review","budget_authorization","confirmation"]'::jsonb,'["executive_veto","judicial_review","board_reserved_authority","CHLOM","human_ratification"]'::jsonb,'{"members_vote_as_eligible_constituents_or_representatives":true,"one_membership_one_vote":true,"quorum_required":true,"rights_sensitive_actions_need_human_ratification":true}'::jsonb,'{"alongside_command_chain":true,"does_not_manage_workers_directly":true}'::jsonb,'active','{"mark":"TM"}'::jsonb),
('penta.branch.judicial','PentaJudicial™','judicial','penta.charter.democratic-governance.v1','Independently adjudicate internal disputes, appeals, election challenges, authority conflicts, due-process claims, and review of executive or legislative actions.','["appeal","stay","review","interpretation","remand","reverse","modify","invalidate_internal_action"]'::jsonb,'["executive_action","legislative_action","disciplinary_action","election_process"]'::jsonb,'["appeal","panel_recusal","board_reserved_authority","CHLOM","external_law_and_contracts"]'::jsonb,'{"no_party_may_judge_own_case":true,"conflict_requires_recusal":true,"D2_D3_minimum_panel":3,"reasons_required":true,"remedies_explicit":true}'::jsonb,'{"independent_from_ordinary_management_chain_for_case_decisions":true,"organizational_internal_only":true}'::jsonb,'active','{"mark":"TM"}'::jsonb)
on conflict (branch_key) do update set canonical_name=excluded.canonical_name,branch_type=excluded.branch_type,charter_key=excluded.charter_key,mandate=excluded.mandate,powers=excluded.powers,checks_on=excluded.checks_on,checked_by=excluded.checked_by,independence_rules=excluded.independence_rules,ordinary_chain_binding=excluded.ordinary_chain_binding,state='active',metadata=public.penta_governance_branches.metadata||excluded.metadata,updated_at=now();

insert into public.penta_constituencies(constituency_key,canonical_name,scope,representation_mode,eligibility_rules,default_quorum_ratio,default_approval_ratio,human_floor_ratio,state,metadata) values
('penta.constituency.workforce','Penta Workforce Electorate™','All eligible governed workers, agents, representatives, and authorized human participants','hybrid','{"must_have_active_governance_membership":true,"scope_specific_eligibility":true,"suspended_memberships_cannot_vote":true,"agent_votes_cannot_satisfy_required_human_ratification":true}'::jsonb,0.5,0.5,0.5,'active','{"democratic_substrate":true}'::jsonb),
('penta.constituency.affected','Affected Constituency™','Subjects materially affected by a specific policy, contract, budget, cohort, right, or governance action','direct','{"material_effect_required":true,"conflicts_must_be_disclosed":true}'::jsonb,0.5,0.5,0.5,'active','{"contextual":true}'::jsonb)
on conflict (constituency_key) do update set canonical_name=excluded.canonical_name,scope=excluded.scope,representation_mode=excluded.representation_mode,eligibility_rules=excluded.eligibility_rules,default_quorum_ratio=excluded.default_quorum_ratio,default_approval_ratio=excluded.default_approval_ratio,human_floor_ratio=excluded.human_floor_ratio,state='active',metadata=public.penta_constituencies.metadata||excluded.metadata,updated_at=now();

insert into public.penta_system_registry(system_key,canonical_name,category,purpose,authority_boundary,risk_ceiling,maturity,version,public_exposure,docs_ref,runtime_ref,metadata,last_verified_at) values
('penta.executive','PentaExecutive','executive_governance','Executes valid directives and enacted governance through the existing Board-Director-Manager administrative chain.','Administrative execution only; cannot manufacture legislative, judicial, provider, legal, or reserved authority.','D3','production','1.0.0',false,'services/penta-governance-v1/README.md','table:penta_executive_actions','{"mark":"TM","branch":"executive"}'::jsonb,now()),
('penta.legislative','PentaLegislative','legislative_governance','Provides democratic initiation, deliberation, amendment, voting, enactment, budget authorization, confirmation, and overrides.','Internal delegated governance only; subject to charter, Board reserved authority, CHLOM, human ratification, and judicial review.','D3','production','1.0.0',false,'services/penta-governance-v1/README.md','table:penta_legislative_items','{"mark":"TM","branch":"legislative"}'::jsonb,now()),
('penta.judicial','PentaJudicial','judicial_governance','Provides independent internal adjudication, appeals, stays, interpretation, remand, and review.','Internal organizational adjudication only; not a court and cannot create external legal rights or sovereign authority.','D3','production','1.0.0',false,'services/penta-governance-v1/README.md','table:penta_judicial_cases','{"mark":"TM","branch":"judicial"}'::jsonb,now()),
('penta.democracy','PentaDemocracy','democratic_governance','Provides constituencies, eligibility, one-member-one-vote ballots, delegation, quorum, referenda, human ratification, and conflict/recusal controls.','Participation informs and authorizes only within valid delegated scope; votes cannot override law, contracts, CHLOM, reserved authority, or provider permissions.','D3','production','1.0.0',false,'services/penta-governance-v1/README.md','schema:penta_three_branch_governance','{"mark":"TM","democratic":true}'::jsonb,now())
on conflict (system_key) do update set canonical_name=excluded.canonical_name,category=excluded.category,purpose=excluded.purpose,authority_boundary=excluded.authority_boundary,risk_ceiling=excluded.risk_ceiling,maturity=excluded.maturity,version=excluded.version,public_exposure=excluded.public_exposure,docs_ref=excluded.docs_ref,runtime_ref=excluded.runtime_ref,metadata=public.penta_system_registry.metadata||excluded.metadata,last_verified_at=now(),updated_at=now();

insert into public.penta_mark_registry(mark_key,canonical_name,display_mark,owner_name,mark_family,symbol,registration_status,jurisdiction,use_status,disclaimer,metadata)
select 'mark.'||regexp_replace(lower(canonical_name),'[^a-z0-9]+','-','g'),canonical_name,canonical_name||'™','CrownThrive, LLC','Penta','TM','unregistered_asserted','US','claimed',canonical_name||'™ is a claimed mark of CrownThrive, LLC. The ™ symbol denotes a claimed mark and does not state federal registration. The ® symbol may be used only after registration is independently verified.',jsonb_build_object('source','penta_system_registry','preserve_penta_name',true)
from public.penta_system_registry where system_key in ('penta.executive','penta.legislative','penta.judicial','penta.democracy')
on conflict (mark_key) do update set display_mark=excluded.display_mark,owner_name=excluded.owner_name,disclaimer=excluded.disclaimer,metadata=public.penta_mark_registry.metadata||excluded.metadata,updated_at=now();

update public.penta_workforce_system_state
set version='1.1.0',
    authority_model='PentaBoard reserved/constitutional authority; PentaExecutive executes through Board-Director-Manager chain; PentaLegislative democratically deliberates and enacts within delegated scope; PentaJudicial independently reviews and adjudicates internal disputes; PentaCohorts and workers execute; all remain bounded by CHLOM and existing authority.',
    metadata=metadata||'{"three_branch_governance":true,"democratic_substrate":true,"executive":"PentaExecutive","legislative":"PentaLegislative","judicial":"PentaJudicial","democracy":"PentaDemocracy"}'::jsonb,
    last_verified_at=now(), updated_at=now()
where system_key='penta.workforce-os';

create index if not exists penta_governance_memberships_subject_idx on public.penta_governance_memberships(subject_ref);
create index if not exists penta_governance_memberships_constituency_idx on public.penta_governance_memberships(constituency_key);
create index if not exists penta_governance_memberships_branch_idx on public.penta_governance_memberships(branch_key);
create index if not exists penta_vote_delegations_delegator_idx on public.penta_vote_delegations(delegator_membership_id);
create index if not exists penta_vote_delegations_delegate_idx on public.penta_vote_delegations(delegate_membership_id);
create index if not exists penta_legislative_items_session_idx on public.penta_legislative_items(session_id);
create index if not exists penta_legislative_items_sponsor_idx on public.penta_legislative_items(sponsor_membership_id);
create index if not exists penta_legislative_amendments_item_idx on public.penta_legislative_amendments(item_id);
create index if not exists penta_ballots_constituency_idx on public.penta_ballots(constituency_key);
create index if not exists penta_ballot_eligibility_membership_idx on public.penta_ballot_eligibility(membership_id);
create index if not exists penta_ballot_votes_membership_idx on public.penta_ballot_votes(membership_id);
create index if not exists penta_executive_actions_issuer_idx on public.penta_executive_actions(issuer_assignment_id);
create index if not exists penta_executive_actions_legislative_idx on public.penta_executive_actions(legislative_item_id);
create index if not exists penta_appointments_nominee_idx on public.penta_appointments(nominee_subject_ref);
create index if not exists penta_judicial_cases_appellant_idx on public.penta_judicial_cases(appellant_subject_ref);
create index if not exists penta_judicial_cases_respondent_idx on public.penta_judicial_cases(respondent_subject_ref);
create index if not exists penta_judicial_panel_members_judge_idx on public.penta_judicial_panel_members(judge_membership_id);
create index if not exists penta_judicial_decisions_case_idx on public.penta_judicial_decisions(case_id);

insert into public.penta_workforce_events(event_type,actor_ref,object_ref,payload)
values('penta_three_branch_democratic_governance_v1_institutionalized','founder-directive:2026-08-26','penta.workforce-os',jsonb_build_object('version','1.1.0','branches',jsonb_build_array('PentaExecutive','PentaLegislative','PentaJudicial'),'democratic_substrate','PentaDemocracy','charter','Penta Democratic Governance Charter','organizational_not_sovereign',true));
