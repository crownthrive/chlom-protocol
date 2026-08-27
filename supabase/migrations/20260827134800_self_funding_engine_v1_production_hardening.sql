-- Self-Funding Business Engine v1 production hardening.
-- Public-safe migration artifact. No credentials or secret material.

alter table public.ct_self_funding_policies drop constraint if exists ct_self_funding_policies_allocation_sum_check;
alter table public.ct_self_funding_policies add constraint ct_self_funding_policies_allocation_sum_check check (provider_bps >= 0 and hq_growth_tech_bps >= 0 and regional_leadership_bps >= 0 and national_ad_bps >= 0 and thrivefund_bps >= 0 and provider_bps + hq_growth_tech_bps + regional_leadership_bps + national_ad_bps + thrivefund_bps = 10000);

alter table public.ct_self_funding_allocations enable row level security;
alter table public.ct_self_funding_contracts enable row level security;
alter table public.ct_self_funding_events enable row level security;
alter table public.ct_self_funding_policies enable row level security;
alter table public.ct_self_funding_provider_bindings enable row level security;
alter table public.ct_self_funding_transactions enable row level security;

drop policy if exists ct_sfe_allocations_service_role on public.ct_self_funding_allocations;
drop policy if exists ct_sfe_contracts_service_role on public.ct_self_funding_contracts;
drop policy if exists ct_sfe_events_service_role on public.ct_self_funding_events;
drop policy if exists ct_sfe_policies_service_role on public.ct_self_funding_policies;
drop policy if exists ct_sfe_provider_bindings_service_role on public.ct_self_funding_provider_bindings;
drop policy if exists ct_sfe_transactions_service_role on public.ct_self_funding_transactions;

create policy ct_sfe_allocations_service_role on public.ct_self_funding_allocations for all to service_role using (true) with check (true);
create policy ct_sfe_contracts_service_role on public.ct_self_funding_contracts for all to service_role using (true) with check (true);
create policy ct_sfe_events_service_role on public.ct_self_funding_events for all to service_role using (true) with check (true);
create policy ct_sfe_policies_service_role on public.ct_self_funding_policies for all to service_role using (true) with check (true);
create policy ct_sfe_provider_bindings_service_role on public.ct_self_funding_provider_bindings for all to service_role using (true) with check (true);
create policy ct_sfe_transactions_service_role on public.ct_self_funding_transactions for all to service_role using (true) with check (true);

create or replace function public.ct_calculate_self_funding_allocations(p_transaction_id uuid)
returns table(allocation_code text, basis_bps integer, amount_minor bigint)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  tx public.ct_self_funding_transactions%rowtype;
  pol public.ct_self_funding_policies%rowtype;
  provider_amt bigint;
  hq_amt bigint;
  regional_amt bigint;
  ad_amt bigint;
  impact_amt bigint;
  total_bps integer;
begin
  select * into tx from public.ct_self_funding_transactions where transaction_id = p_transaction_id for update;
  if not found then raise exception 'transaction_not_found'; end if;
  select * into pol from public.ct_self_funding_policies where policy_key = tx.policy_key and state = 'active';
  if not found then raise exception 'active_policy_not_found'; end if;
  total_bps := pol.provider_bps + pol.hq_growth_tech_bps + pol.regional_leadership_bps + pol.national_ad_bps + pol.thrivefund_bps;
  if total_bps <> 10000 then raise exception 'policy_allocation_must_equal_10000_bps'; end if;
  if tx.compliance_state <> 'pass' or tx.rights_state <> 'pass' then raise exception 'transaction_not_eligible'; end if;
  provider_amt := ((tx.gross_minor::numeric * pol.provider_bps) / 10000)::bigint;
  hq_amt := ((tx.gross_minor::numeric * pol.hq_growth_tech_bps) / 10000)::bigint;
  regional_amt := ((tx.gross_minor::numeric * pol.regional_leadership_bps) / 10000)::bigint;
  ad_amt := ((tx.gross_minor::numeric * pol.national_ad_bps) / 10000)::bigint;
  impact_amt := tx.gross_minor - provider_amt - hq_amt - regional_amt - ad_amt;
  if provider_amt + hq_amt + regional_amt + ad_amt + impact_amt <> tx.gross_minor then raise exception 'allocation_total_mismatch'; end if;
  delete from public.ct_self_funding_allocations where transaction_id = p_transaction_id and state in ('calculated','hold','failed');
  insert into public.ct_self_funding_allocations(transaction_id,allocation_code,destination_ref,basis_bps,amount_minor,state)
  values
    (p_transaction_id,'PROVIDER',tx.provider_ref,pol.provider_bps,provider_amt,'calculated'),
    (p_transaction_id,'HQ_GROWTH_TECH','hq_growth_technology',pol.hq_growth_tech_bps,hq_amt,'calculated'),
    (p_transaction_id,'REGIONAL_LEADERSHIP','regional_leadership',pol.regional_leadership_bps,regional_amt,'calculated'),
    (p_transaction_id,'NATIONAL_AD','national_ad_fund',pol.national_ad_bps,ad_amt,'calculated'),
    (p_transaction_id,'THRIVEFUND','thrivefund',pol.thrivefund_bps,impact_amt,'calculated');
  update public.ct_self_funding_transactions set allocation_state = 'calculated', updated_at = now() where transaction_id = p_transaction_id;
  insert into public.ct_self_funding_events(event_type,transaction_id,idempotency_key,payload)
  values('allocation.calculated',p_transaction_id,tx.idempotency_key,jsonb_build_object('policy_key',pol.policy_key,'policy_version',pol.version,'gross_minor',tx.gross_minor,'total_bps',total_bps));
  return query select a.allocation_code,a.basis_bps,a.amount_minor from public.ct_self_funding_allocations a where a.transaction_id = p_transaction_id order by a.allocation_code;
end;
$function$;

revoke all on function public.ct_calculate_self_funding_allocations(uuid) from public;
revoke execute on function public.ct_calculate_self_funding_allocations(uuid) from anon, authenticated;
grant execute on function public.ct_calculate_self_funding_allocations(uuid) to service_role;
