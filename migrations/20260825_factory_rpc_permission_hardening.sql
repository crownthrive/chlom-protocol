-- CrownThrive™ Autonomous Software Factory v2 RPC permission hardening
-- Copyright (c) 2026 CrownThrive, LLC. All rights reserved.

revoke all on function public.ct_factory_claim_work(text,integer) from public,anon,authenticated;
revoke all on function public.ct_factory_complete_work(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.ct_factory_reconcile_run(uuid) from public,anon,authenticated;
revoke all on function public.ct_factory_seed_run(uuid) from public,anon,authenticated;
revoke all on function public.ct_factory_tick() from public,anon,authenticated;

grant execute on function public.ct_factory_claim_work(text,integer) to service_role,postgres;
grant execute on function public.ct_factory_complete_work(uuid,text,jsonb) to service_role,postgres;
grant execute on function public.ct_factory_reconcile_run(uuid) to service_role,postgres;
grant execute on function public.ct_factory_seed_run(uuid) to service_role,postgres;
grant execute on function public.ct_factory_tick() to service_role,postgres;
