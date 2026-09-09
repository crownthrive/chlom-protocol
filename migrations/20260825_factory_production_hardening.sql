-- CrownThrive™ Autonomous Software Factory v2 production hardening
-- Copyright (c) 2026 CrownThrive, LLC. All rights reserved.

create table if not exists public.ct_factory_deployments (
  id uuid primary key default gen_random_uuid(),
  build_run_id uuid not null references public.ct_factory_build_runs(id) on delete cascade,
  target_id uuid not null references public.ct_factory_deployment_targets(id) on delete restrict,
  state text not null check (state in ('requested','implemented','failed','rolled_back')),
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(build_run_id,target_id)
);
create index if not exists ct_factory_deployments_run_idx on public.ct_factory_deployments(build_run_id);
alter table public.ct_factory_deployments enable row level security;

do $$
begin
  if not exists(select 1 from vault.decrypted_secrets where name='ct_factory_worker_token') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'ct_factory_worker_token','CrownThrive Software Factory worker dispatch token');
  end if;
end $$;

create or replace function public.ct_factory_authorize_worker(p_token text)
returns boolean language sql security definer set search_path=public,vault,extensions,pg_catalog as $$
  select p_token is not null and exists(
    select 1 from vault.decrypted_secrets where name='ct_factory_worker_token'
      and encode(extensions.digest(p_token,'sha256'),'hex')=encode(extensions.digest(decrypted_secret,'sha256'),'hex')
  );
$$;
revoke all on function public.ct_factory_authorize_worker(text) from public,anon,authenticated;
grant execute on function public.ct_factory_authorize_worker(text) to service_role;

create or replace function public.ct_factory_dispatch_worker(p_limit integer default 8)
returns jsonb language plpgsql security definer set search_path=public,vault,net,pg_catalog as $$
declare v_token text; v_request_id bigint; v_limit integer:=greatest(1,least(coalesce(p_limit,8),16));
begin
  select decrypted_secret into v_token from vault.decrypted_secrets where name='ct_factory_worker_token' order by created_at desc limit 1;
  if v_token is null then raise exception 'CT_FACTORY_WORKER_TOKEN_UNAVAILABLE'; end if;
  v_request_id:=net.http_post(
    url:='https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/ct-software-factory-worker',
    body:=jsonb_build_object('action','drain','limit',v_limit),
    headers:=jsonb_build_object('content-type','application/json','x-ct-factory-token',v_token),
    timeout_milliseconds:=120000
  );
  insert into public.ct_factory_events(event_type,entity_type,payload) values('factory.worker.dispatched','factory',jsonb_build_object('request_id',v_request_id,'limit',v_limit));
  return jsonb_build_object('state','requested','request_id',v_request_id,'limit',v_limit);
end $$;
revoke all on function public.ct_factory_dispatch_worker(integer) from public,anon,authenticated;
grant execute on function public.ct_factory_dispatch_worker(integer) to service_role,postgres;

create or replace function public.ct_factory_dispatch_tick()
returns jsonb language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_tick jsonb; v_dispatch jsonb;
begin
  v_tick:=public.ct_factory_tick();
  v_dispatch:=public.ct_factory_dispatch_worker(8);
  return jsonb_build_object('tick',v_tick,'dispatch',v_dispatch,'at',now());
end $$;
revoke all on function public.ct_factory_dispatch_tick() from public,anon,authenticated;
grant execute on function public.ct_factory_dispatch_tick() to service_role,postgres;

select cron.unschedule('ct-software-factory-tick-v2') where exists(select 1 from cron.job where jobname='ct-software-factory-tick-v2');
select cron.schedule('ct-software-factory-dispatch-v3','* * * * *','select public.ct_factory_dispatch_tick();') where not exists(select 1 from cron.job where jobname='ct-software-factory-dispatch-v3');

update public.ct_factory_projects
set repo_full_name='crownthrive1/chlom-protocol', production_enabled=true,
    build_contract=coalesce(build_contract,'{}'::jsonb)||jsonb_build_object(
      'source_of_truth','crownthrive1/chlom-protocol',
      'rights_owner','CrownThrive, LLC',
      'trademark_notice','CrownThrive™ Autonomous Software Factory; ThriveBase™; CHLOM™',
      'trademark_scope','common-law notice; no claim of federal registration by this migration'
    ), updated_at=now()
where project_key='crownthrive-os-v2-factory';

with p as (select id from public.ct_factory_projects where project_key='crownthrive-os-v2-factory')
insert into public.ct_factory_deployment_targets(project_id,target_key,target_type,endpoint,config,enabled,production)
select id,'thrivebase-software-factory','supabase_edge','https://tzajnzshmtzjenqulehq.supabase.co/functions/v1',jsonb_build_object(
  'functions',jsonb_build_array('ct-software-factory-worker','ct-factory-generator','ct-factory-test-runner','ct-factory-deployer'),
  'control_plane','ThriveBase','source_of_truth','crownthrive1/chlom-protocol'
),true,true from p on conflict do nothing;
