-- Penta Workforce OS v1
-- CrownThrive Phase 3 living agent/workforce governance layer.
-- Additive, fail-closed, private-by-default. No money movement, legal filing,
-- employment-status determination, medical decisioning, or authority manufacture.

create table if not exists public.penta_workforce_system_state (
  system_key text primary key,
  canonical_name text not null,
  version text not null,
  state text not null check (state in ('controlled_test','production','maintenance','retired')),
  authority_model text not null,
  founder_directive_ref text,
  no_authority_manufacture boolean not null default true,
  money_movement boolean not null default false,
  medical_decisioning boolean not null default false,
  trademark_mode text not null default 'TM_ASSERTED',
  metadata jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_workforce_roles (
  role_key text primary key,
  canonical_name text not null,
  authority_rank integer not null check (authority_rank between 0 and 500),
  role_class text not null,
  can_issue jsonb not null default '[]'::jsonb,
  can_manage_below_rank boolean not null default false,
  cross_cutting boolean not null default false,
  authority_boundary text not null,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_workforce_subjects (
  subject_ref text primary key,
  subject_type text not null check (subject_type in ('human','agent','service','governance_body')),
  display_name text not null,
  source_system text,
  source_ref text,
  lifecycle_state text not null default 'active' check (lifecycle_state in ('candidate','active','paused','suspended','retired','expired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_workforce_units (
  unit_key text primary key,
  canonical_name text not null,
  unit_type text not null check (unit_type in ('board','directorate','management','cohort','legal','hr','operations','accelerator')),
  parent_unit_key text references public.penta_workforce_units(unit_key),
  lead_subject_ref text references public.penta_workforce_subjects(subject_ref),
  authority_rank integer not null check (authority_rank between 0 and 500),
  state text not null default 'active' check (state in ('forming','active','paused','retired')),
  charter jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_workforce_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  assignment_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  role_key text not null references public.penta_workforce_roles(role_key),
  unit_key text references public.penta_workforce_units(unit_key),
  manager_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  scope jsonb not null default '{}'::jsonb,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  state text not null default 'active' check (state in ('pending','active','paused','suspended','expired','retired')),
  source_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.penta_governance_instruments (
  instrument_id uuid primary key default gen_random_uuid(),
  instrument_key text not null unique,
  instrument_kind text not null check (instrument_kind in ('directive','policy','sop','sla','contract','task_order','legal_hold','legal_advisory')),
  title text not null,
  issuer_assignment_id uuid not null references public.penta_workforce_assignments(assignment_id),
  approved_by_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  parent_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  target_unit_key text references public.penta_workforce_units(unit_key),
  target_subject_ref text references public.penta_workforce_subjects(subject_ref),
  target_max_rank integer check (target_max_rank between 0 and 500),
  authority_ref text not null,
  body jsonb not null default '{}'::jsonb,
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  state text not null default 'active' check (state in ('draft','active','superseded','expired','revoked')),
  supersedes_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (approved_by_assignment_id is null or approved_by_assignment_id <> issuer_assignment_id),
  check (expires_at is null or expires_at > effective_at)
);

create table if not exists public.penta_cohorts (
  cohort_key text primary key,
  canonical_name text not null,
  manager_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  purpose text not null,
  contract_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  state text not null default 'forming' check (state in ('forming','active','paused','completed','retired')),
  success_criteria jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.penta_cohort_members (
  cohort_key text not null references public.penta_cohorts(cohort_key) on delete cascade,
  assignment_id uuid not null references public.penta_workforce_assignments(assignment_id),
  cohort_role text not null default 'member',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  state text not null default 'active' check (state in ('invited','active','paused','completed','removed')),
  metadata jsonb not null default '{}'::jsonb,
  primary key (cohort_key, assignment_id)
);

create table if not exists public.penta_notes (
  note_id uuid primary key default gen_random_uuid(),
  note_key text not null unique,
  author_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  subject_ref text references public.penta_workforce_subjects(subject_ref),
  cohort_key text references public.penta_cohorts(cohort_key),
  category text not null check (category in ('feedback','proposal','breakdown','win','luck_signal','risk','commendation','process_gap','incident_observation')),
  title text not null,
  body text not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  visibility text not null default 'internal' check (visibility in ('private','unit','cohort','internal','public_sanitized')),
  state text not null default 'open' check (state in ('open','under_review','accepted','rejected','implemented','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_note_votes (
  note_id uuid not null references public.penta_notes(note_id) on delete cascade,
  voter_assignment_id uuid not null references public.penta_workforce_assignments(assignment_id),
  stance text not null check (stance in ('support','oppose','abstain','needs_evidence')),
  rationale text,
  weight numeric not null default 1 check (weight > 0 and weight <= 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (note_id, voter_assignment_id)
);

create table if not exists public.penta_triage_cases (
  case_id uuid primary key default gen_random_uuid(),
  case_key text not null unique,
  source_note_id uuid references public.penta_notes(note_id),
  subject_ref text references public.penta_workforce_subjects(subject_ref),
  severity text not null check (severity in ('P0','P1','P2','P3','P4')),
  case_type text not null,
  summary text not null,
  routed_system text not null,
  owner_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  evidence_refs jsonb not null default '[]'::jsonb,
  state text not null default 'open' check (state in ('open','acknowledged','contained','investigating','remediating','resolved','closed')),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_health_snapshots (
  snapshot_id uuid primary key default gen_random_uuid(),
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  health_domain text not null check (health_domain in ('agent_runtime','workload','safety','availability')),
  status text not null check (status in ('green','amber','red','unknown')),
  capacity_score numeric check (capacity_score between 0 and 100),
  heartbeat_at timestamptz,
  workload_units numeric,
  error_rate numeric check (error_rate is null or (error_rate >= 0 and error_rate <= 1)),
  medical_data_allowed boolean not null default false check (medical_data_allowed = false),
  observations jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.penta_hr_cases (
  case_id uuid primary key default gen_random_uuid(),
  case_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  opened_by_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  case_type text not null check (case_type in ('onboarding','offboarding','role_change','grievance','conduct','performance','accommodation_routing','policy_acknowledgement')),
  summary text not null,
  policy_refs jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  state text not null default 'open' check (state in ('open','review','action_pending','resolved','closed')),
  decision_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  appeal_available boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_benefit_entitlements (
  entitlement_id uuid primary key default gen_random_uuid(),
  entitlement_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  benefit_type text not null,
  policy_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  eligibility_basis jsonb not null default '{}'::jsonb,
  state text not null default 'proposed' check (state in ('proposed','eligible','active','paused','expired','revoked')),
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_pay_entries (
  pay_entry_id uuid primary key default gen_random_uuid(),
  pay_key text not null unique,
  beneficiary_subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  contract_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  approved_by_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  currency text not null default 'USD',
  gross_minor bigint not null check (gross_minor >= 0),
  entry_type text not null check (entry_type in ('stipend','fee','milestone','royalty_accrual','reimbursement','credit','adjustment')),
  state text not null default 'proposed' check (state in ('proposed','approved','eligible','held','paid_external','cancelled')),
  provider_money_movement boolean not null default false check (provider_money_movement = false),
  external_receipt_ref text,
  due_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (state <> 'paid_external' or external_receipt_ref is not null)
);

create table if not exists public.penta_cost_budgets (
  budget_id uuid primary key default gen_random_uuid(),
  budget_key text not null unique,
  scope_ref text not null,
  owner_subject_ref text references public.penta_workforce_subjects(subject_ref),
  policy_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  currency text not null default 'USD',
  soft_limit_minor bigint not null default 0 check (soft_limit_minor >= 0),
  hard_limit_minor bigint not null check (hard_limit_minor >= 0),
  committed_minor bigint not null default 0 check (committed_minor >= 0),
  spent_minor bigint not null default 0 check (spent_minor >= 0),
  state text not null default 'active' check (state in ('planned','active','held','exhausted','closed')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (soft_limit_minor <= hard_limit_minor),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.penta_cost_events (
  event_id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  budget_id uuid not null references public.penta_cost_budgets(budget_id),
  subject_ref text references public.penta_workforce_subjects(subject_ref),
  assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  event_kind text not null check (event_kind in ('commit','release','spend','refund')),
  amount_minor bigint not null check (amount_minor > 0),
  authority_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  evidence_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.penta_accelerator_records (
  record_id uuid primary key default gen_random_uuid(),
  record_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  cohort_key text references public.penta_cohorts(cohort_key),
  sponsor_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  stage text not null check (stage in ('nominated','screening','accelerating','graduated','paused','exited')),
  score numeric check (score between 0 and 100),
  objectives jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  next_review_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.penta_ramifications (
  ramification_id uuid primary key default gen_random_uuid(),
  ramification_key text not null unique,
  subject_ref text not null references public.penta_workforce_subjects(subject_ref),
  source_note_id uuid references public.penta_notes(note_id),
  source_case_id uuid references public.penta_triage_cases(case_id),
  action_type text not null check (action_type in ('recognition','accelerator_nomination','remediation','restriction','contract_review','cost_hold','pay_hold')),
  authority_instrument_id uuid references public.penta_governance_instruments(instrument_id),
  issued_by_assignment_id uuid references public.penta_workforce_assignments(assignment_id),
  rationale text not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  review_state text not null default 'pending' check (review_state in ('pending','approved','active','appealed','reversed','completed','cancelled')),
  appeal_available boolean not null default true,
  effective_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    action_type in ('recognition','accelerator_nomination')
    or authority_instrument_id is not null
  )
);

create table if not exists public.penta_mark_registry (
  mark_key text primary key,
  canonical_name text not null,
  display_mark text not null,
  owner_name text not null default 'CrownThrive, LLC',
  mark_family text not null default 'Penta',
  symbol text not null default 'TM' check (symbol in ('TM','SM','R')),
  registration_status text not null default 'unregistered_asserted' check (registration_status in ('unregistered_asserted','application_pending','registered','abandoned','retired')),
  jurisdiction text not null default 'US',
  use_status text not null default 'claimed',
  first_use_ref text,
  registration_number text,
  disclaimer text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((symbol <> 'R') or (registration_status = 'registered' and registration_number is not null))
);

create table if not exists public.penta_workforce_events (
  event_id bigint generated always as identity primary key,
  event_type text not null,
  actor_ref text,
  subject_ref text,
  object_ref text,
  trace_id uuid not null default gen_random_uuid(),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Private by default. All access is server-side / governed runtime only.

