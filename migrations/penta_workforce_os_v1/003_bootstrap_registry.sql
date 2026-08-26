insert into public.penta_workforce_system_state(
  system_key,canonical_name,version,state,authority_model,founder_directive_ref,
  no_authority_manufacture,money_movement,medical_decisioning,trademark_mode,metadata,last_verified_at
) values (
  'penta.workforce-os','PentaWorkforce OS','1.0.0','production',
  'PentaBoard > PentaDirectors > PentaManagers > PentaCohorts > workers/agents; cross-cutting controls are bounded and do not manufacture authority',
  'founder-directive:2026-08-26:penta-workforce-environment',
  true,false,false,'TM_ASSERTED',
  '{"phase":"3","runtime":"ThriveBase","living_environment":true,"fail_closed":true,"votes_advisory_until_authorized":true}'::jsonb,
  now()
)
on conflict (system_key) do update set
  canonical_name=excluded.canonical_name,
  version=excluded.version,
  state=excluded.state,
  authority_model=excluded.authority_model,
  founder_directive_ref=excluded.founder_directive_ref,
  metadata=public.penta_workforce_system_state.metadata || excluded.metadata,
  last_verified_at=now(),
  updated_at=now();

insert into public.penta_workforce_roles(
  role_key,canonical_name,authority_rank,role_class,can_issue,can_manage_below_rank,cross_cutting,authority_boundary,metadata
) values
('penta.role.board','PentaBoard',500,'governance','["directive"]'::jsonb,true,false,
 'Issues ecosystem directives. Cannot manufacture law, contractual rights, provider authority, or unbounded execution authority.',
 '{"symbol":"™"}'::jsonb),
('penta.role.legal','PentaLegal',450,'legal_control','["legal_hold","legal_advisory"]'::jsonb,false,true,
 'Provides legal-control gates, holds and advisories. Does not represent court authority or legal filing completion unless independently evidenced.',
 '{"symbol":"™","blocking_control":true}'::jsonb),
('penta.role.director','PentaDirectors',400,'supervision','["policy","sop","sla"]'::jsonb,true,false,
 'Supervises all lower ranks and issues policies, SOPs and SLAs within Board directives and CHLOM authority.',
 '{"symbol":"™"}'::jsonb),
('penta.role.hr','PentaHR',350,'workforce_control','[]'::jsonb,false,true,
 'Administers role lifecycle and cases under policy; cannot unilaterally create governance authority.',
 '{"symbol":"™"}'::jsonb),
('penta.role.manager','PentaManagers',300,'management','["contract","task_order"]'::jsonb,true,false,
 'Manages lower-rank agents/workers and issues bounded contracts/task orders within policy, SLA, budget and authority constraints.',
 '{"symbol":"™"}'::jsonb),
('penta.role.cohort','PentaCohorts',200,'cohort','[]'::jsonb,false,false,
 'Mission/team participation layer; cohort membership does not create higher authority.',
 '{"symbol":"™"}'::jsonb),
('penta.role.worker','PentaWorkers',100,'worker','[]'::jsonb,false,false,
 'Executes assigned contracts/tasks within explicit scope, TTL, cost, safety and governance constraints.',
 '{"symbol":"™"}'::jsonb)
on conflict (role_key) do update set
  canonical_name=excluded.canonical_name,
  authority_rank=excluded.authority_rank,
  role_class=excluded.role_class,
  can_issue=excluded.can_issue,
  can_manage_below_rank=excluded.can_manage_below_rank,
  cross_cutting=excluded.cross_cutting,
  authority_boundary=excluded.authority_boundary,
  metadata=public.penta_workforce_roles.metadata || excluded.metadata,
  active=true,
  updated_at=now();

insert into public.penta_workforce_subjects(subject_ref,subject_type,display_name,source_system,source_ref,lifecycle_state,metadata)
values
('ct.body.penta-board','governance_body','PentaBoard','PentaWorkforce OS','bootstrap','active','{"bootstrap":true}'::jsonb),
('ct.body.penta-directors','governance_body','PentaDirectors','PentaWorkforce OS','bootstrap','active','{"bootstrap":true}'::jsonb),
('ct.body.penta-managers','governance_body','PentaManagers','PentaWorkforce OS','bootstrap','active','{"bootstrap":true}'::jsonb),
('ct.body.penta-legal','governance_body','PentaLegal','PentaWorkforce OS','bootstrap','active','{"bootstrap":true}'::jsonb),
('ct.body.penta-hr','governance_body','PentaHR','PentaWorkforce OS','bootstrap','active','{"bootstrap":true}'::jsonb)
on conflict (subject_ref) do update set
  display_name=excluded.display_name,
  lifecycle_state='active',
  metadata=public.penta_workforce_subjects.metadata || excluded.metadata,
  updated_at=now();

insert into public.penta_workforce_units(unit_key,canonical_name,unit_type,parent_unit_key,lead_subject_ref,authority_rank,state,charter)
values
('penta.unit.board','PentaBoard','board',null,'ct.body.penta-board',500,'active','{"issues":["directives"],"scope":"all_below"}'::jsonb),
('penta.unit.directors','PentaDirectors','directorate','penta.unit.board','ct.body.penta-directors',400,'active','{"issues":["policy","sop","sla"],"scope":"all_below"}'::jsonb),
('penta.unit.legal','PentaLegal','legal','penta.unit.board','ct.body.penta-legal',450,'active','{"cross_cutting":true,"issues":["legal_hold","legal_advisory"]}'::jsonb),
('penta.unit.managers','PentaManagers','management','penta.unit.directors','ct.body.penta-managers',300,'active','{"issues":["contract","task_order"],"scope":"agents_and_workers_below"}'::jsonb),
('penta.unit.hr','PentaHR','hr','penta.unit.directors','ct.body.penta-hr',350,'active','{"cross_cutting":true}'::jsonb)
on conflict (unit_key) do update set
  canonical_name=excluded.canonical_name,
  unit_type=excluded.unit_type,
  parent_unit_key=excluded.parent_unit_key,
  lead_subject_ref=excluded.lead_subject_ref,
  authority_rank=excluded.authority_rank,
  state='active',
  charter=public.penta_workforce_units.charter || excluded.charter,
  updated_at=now();

insert into public.penta_workforce_assignments(assignment_key,subject_ref,role_key,unit_key,scope,state,source_ref,metadata)
values
('penta.assignment.board.bootstrap','ct.body.penta-board','penta.role.board','penta.unit.board','{"scope":"ecosystem"}'::jsonb,'active','founder-directive:2026-08-26','{"bootstrap_governance_body":true}'::jsonb),
('penta.assignment.directors.bootstrap','ct.body.penta-directors','penta.role.director','penta.unit.directors','{"scope":"all_below_board"}'::jsonb,'active','founder-directive:2026-08-26','{"bootstrap_governance_body":true}'::jsonb),
('penta.assignment.managers.bootstrap','ct.body.penta-managers','penta.role.manager','penta.unit.managers','{"scope":"agents_and_workers"}'::jsonb,'active','founder-directive:2026-08-26','{"bootstrap_governance_body":true}'::jsonb),
('penta.assignment.legal.bootstrap','ct.body.penta-legal','penta.role.legal','penta.unit.legal','{"scope":"legal_control"}'::jsonb,'active','founder-directive:2026-08-26','{"bootstrap_governance_body":true}'::jsonb),
('penta.assignment.hr.bootstrap','ct.body.penta-hr','penta.role.hr','penta.unit.hr','{"scope":"workforce_lifecycle"}'::jsonb,'active','founder-directive:2026-08-26','{"bootstrap_governance_body":true}'::jsonb)
on conflict (assignment_key) do update set
  role_key=excluded.role_key,
  unit_key=excluded.unit_key,
  scope=excluded.scope,
  state='active',
  metadata=public.penta_workforce_assignments.metadata || excluded.metadata,
  updated_at=now();

insert into public.penta_governance_instruments(
  instrument_key,instrument_kind,title,issuer_assignment_id,target_max_rank,authority_ref,body,state,metadata
)
select
  'PBD-BOOTSTRAP-20260826','directive','Penta Workforce Operating Directive',
  a.assignment_id,499,'founder-directive:2026-08-26:penta-workforce-environment',
  '{
    "hierarchy":["PentaBoard","PentaDirectors","PentaManagers","PentaCohorts","workers_and_agents"],
    "cross_cutting":["PentaLegal","PentaHR","PentaBenefits","PentaPay","PentaCost","PentaHealth","PentaTriage","PentaNotes","PentaAccelerator"],
    "rules":{
      "board_issues":"directives",
      "directors_issue":["policies","SOPs","SLAs"],
      "managers_issue":["contracts","task_orders"],
      "votes_do_not_self_execute_punishment":true,
      "cost_hard_caps":true,
      "pay_self_approval":false,
      "money_movement_requires_separate_authority":true,
      "medical_decisioning":false,
      "appeal_preserved_for_restrictive_ramifications":true
    }
  }'::jsonb,
  'active','{"bootstrap":true,"phase":"3"}'::jsonb
from public.penta_workforce_assignments a
where a.assignment_key='penta.assignment.board.bootstrap'
on conflict (instrument_key) do update set
  body=excluded.body,state='active',updated_at=now();

-- Register requested Penta institutional systems.
insert into public.penta_system_registry(
  system_key,canonical_name,category,purpose,authority_boundary,risk_ceiling,maturity,version,
  public_exposure,docs_ref,runtime_ref,metadata,last_verified_at
) values
('penta.workforce','PentaWorkforce','workforce_operating_system','Living governance/workforce environment for agents, workers and governed bodies.',
 'Coordinates roles and controls but never manufactures authority.','D3','production','1.0.0',false,'services/penta-workforce-v1/README.md','schema:penta_workforce','{"mark":"TM"}'::jsonb,now()),
('penta.board','PentaBoard','governance_directives','Issues directives to subordinate Penta bodies and governed workers.',
 'Directives remain bounded by CHLOM, law, contracts, rights and explicit authority.','D3','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_governance_instruments','{"mark":"TM"}'::jsonb,now()),
('penta.directors','PentaDirectors','supervisory_policy','Supervises lower layers and issues policies, SOPs and SLAs.',
 'Cannot issue above its rank or bypass Board/CHLOM constraints.','D3','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_governance_instruments','{"mark":"TM"}'::jsonb,now()),
('penta.managers','PentaManagers','agent_management','Manages agents/workers and issues bounded contracts and task orders.',
 'Contracts require existing policy, scope, budget and authority; no self-escalation.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_workforce_assignments','{"mark":"TM"}'::jsonb,now()),
('penta.cohorts','PentaCohorts','cohort_operations','Forms governed teams around missions, contracts and success criteria.',
 'Cohort membership does not create governance authority.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_cohorts','{"mark":"TM"}'::jsonb,now()),
('penta.accelerator','PentaAccelerator','workforce_acceleration','Progression, development and graduation pathway for agents/workers.',
 'Progression is evidence-based and cannot silently expand authority.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_accelerator_records','{"mark":"TM"}'::jsonb,now()),
('penta.notes','PentaNotes','feedback_deliberation','Captures feedback, proposals, breakdowns, wins, luck signals, risks and voting.',
 'Votes are deliberative evidence and do not self-execute punishment or authority changes.','D1','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_notes','{"mark":"TM"}'::jsonb,now()),
('penta.triage','PentaTriage','incident_triage','Routes incidents, breakdowns and urgent operational conditions to accountable owners.',
 'Triage may contain and route but does not manufacture final disciplinary/legal authority.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_triage_cases','{"mark":"TM"}'::jsonb,now()),
('penta.health','PentaHealth','operational_health','Tracks agent/runtime health, workload, safety and availability.',
 'No medical diagnosis or protected-health-based employment/benefit decisioning.','D1','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_health_snapshots','{"mark":"TM","medical_data":false}'::jsonb,now()),
('penta.hr','PentaHR','workforce_lifecycle','Administers onboarding, offboarding, grievances, role changes and policy acknowledgement.',
 'HR actions require policy/authority and preserve review/appeal where applicable.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_hr_cases','{"mark":"TM"}'::jsonb,now()),
('penta.benefits','PentaBenefits','benefits_entitlements','Tracks benefit/credit eligibility and governed entitlements.',
 'Eligibility ledger only; no medical decisioning or unauthorized economic promise.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_benefit_entitlements','{"mark":"TM"}'::jsonb,now()),
('penta.pay','PentaPay','compensation_ledger','Tracks compensation eligibility, approvals, holds and external payment receipts.',
 'Ledger/authorization only; never directly moves money and prohibits self-approval.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_pay_entries','{"mark":"TM","money_movement":false}'::jsonb,now()),
('penta.cost','PentaCost','cost_governance','Enforces budgets, commitments, spends, refunds and hard caps to prevent abuse.',
 'Hard limits fail closed; spend authority must already exist.','D2','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_cost_budgets','{"mark":"TM","hard_cap":true}'::jsonb,now()),
('penta.legal','PentaLegal','legal_control','Issues bounded legal holds/advisories and routes legal review.',
 'Does not claim attorney-client relationship, court authority, filing completion or legal conclusion without evidence.','D3','production','1.0.0',false,'services/penta-workforce-v1/README.md','table:penta_governance_instruments','{"mark":"TM"}'::jsonb,now())
on conflict (system_key) do update set
  canonical_name=excluded.canonical_name,
  category=excluded.category,
  purpose=excluded.purpose,
  authority_boundary=excluded.authority_boundary,
  risk_ceiling=excluded.risk_ceiling,
  maturity=excluded.maturity,
  version=excluded.version,
  public_exposure=excluded.public_exposure,
  docs_ref=excluded.docs_ref,
  runtime_ref=excluded.runtime_ref,
  metadata=public.penta_system_registry.metadata || excluded.metadata,
  last_verified_at=now(),
  updated_at=now();
