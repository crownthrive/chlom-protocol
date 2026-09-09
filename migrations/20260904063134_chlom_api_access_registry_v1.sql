begin;

create table if not exists chlom_protocol.api_operator_versions_v1 (
  operator_subject_id text not null,
  version integer not null check (version > 0),
  user_id uuid not null references auth.users(id) on delete restrict,
  authority_class text not null check (authority_class in ('D0','D1','D2','D3')),
  active boolean not null default true,
  scopes text[] not null default '{}'::text[],
  previous_record_hash text check (
    previous_record_hash is null or previous_record_hash ~ '^[0-9a-f]{64}$'
  ),
  record_hash text not null check (record_hash ~ '^[0-9a-f]{64}$'),
  approval_id text not null,
  evidence jsonb not null default '{}'::jsonb,
  dail_event_id uuid not null,
  dail_sequence_id bigint not null,
  dail_event_hash text not null check (dail_event_hash ~ '^[0-9a-f]{64}$'),
  recorded_at timestamptz not null default now(),
  recorded_by text not null,
  primary key (operator_subject_id, version),
  unique (record_hash)
);

create index if not exists api_operator_versions_v1_user_idx
  on chlom_protocol.api_operator_versions_v1(user_id, version desc);

create table if not exists chlom_protocol.api_dispatch_receipts_v1 (
  dispatch_receipt_id uuid primary key,
  request_id uuid not null unique,
  operator_subject_id text not null,
  operator_user_id uuid not null,
  action text not null,
  required_scope text not null,
  required_authority_class text not null check (
    required_authority_class in ('D0','D1','D2','D3')
  ),
  result_sha256 text not null check (result_sha256 ~ '^[0-9a-f]{64}$'),
  result_state text not null,
  dail_event_id uuid not null,
  dail_sequence_id bigint not null,
  dail_event_hash text not null check (dail_event_hash ~ '^[0-9a-f]{64}$'),
  recorded_at timestamptz not null default now()
);

create index if not exists api_dispatch_receipts_v1_operator_idx
  on chlom_protocol.api_dispatch_receipts_v1(operator_subject_id, recorded_at desc);

create index if not exists api_dispatch_receipts_v1_action_idx
  on chlom_protocol.api_dispatch_receipts_v1(action, recorded_at desc);

alter table chlom_protocol.api_operator_versions_v1 enable row level security;
alter table chlom_protocol.api_operator_versions_v1 force row level security;
alter table chlom_protocol.api_dispatch_receipts_v1 enable row level security;
alter table chlom_protocol.api_dispatch_receipts_v1 force row level security;

revoke all on chlom_protocol.api_operator_versions_v1
  from public, anon, authenticated;
revoke all on chlom_protocol.api_dispatch_receipts_v1
  from public, anon, authenticated;

grant all on chlom_protocol.api_operator_versions_v1 to service_role;
grant all on chlom_protocol.api_dispatch_receipts_v1 to service_role;

drop trigger if exists api_operator_versions_v1_append_only
  on chlom_protocol.api_operator_versions_v1;
create trigger api_operator_versions_v1_append_only
before update or delete on chlom_protocol.api_operator_versions_v1
for each row execute function chlom_protocol.reject_append_only_mutation_v1();

drop trigger if exists api_dispatch_receipts_v1_append_only
  on chlom_protocol.api_dispatch_receipts_v1;
create trigger api_dispatch_receipts_v1_append_only
before update or delete on chlom_protocol.api_dispatch_receipts_v1
for each row execute function chlom_protocol.reject_append_only_mutation_v1();

create or replace view chlom_protocol.current_api_operators_v1
with (security_invoker=false, security_barrier=true)
as
select distinct on (o.user_id)
  o.operator_subject_id,
  o.version,
  o.user_id,
  o.authority_class,
  o.active,
  o.scopes,
  o.record_hash,
  o.approval_id,
  o.evidence,
  o.dail_event_id,
  o.dail_sequence_id,
  o.dail_event_hash,
  o.recorded_at,
  o.recorded_by
from chlom_protocol.api_operator_versions_v1 o
order by o.user_id, o.version desc, o.recorded_at desc;

revoke all on chlom_protocol.current_api_operators_v1
  from public, anon, authenticated;
grant select on chlom_protocol.current_api_operators_v1 to service_role;

create or replace function chlom_protocol.authority_rank_v1(
  p_authority_class text
)
returns integer
language sql
immutable
parallel safe
set search_path = 'pg_catalog'
as $$
  select case p_authority_class
    when 'D0' then 0
    when 'D1' then 1
    when 'D2' then 2
    when 'D3' then 3
    else -1
  end
$$;

revoke all on function chlom_protocol.authority_rank_v1(text)
  from public, anon, authenticated;
grant execute on function chlom_protocol.authority_rank_v1(text)
  to service_role;

commit;
