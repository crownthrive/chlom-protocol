-- CHLOM mesh public status: keep the database RPC service-role-only.
--
-- Deployment order is intentional:
--   1. deploy chlom-mesh-status with SUPABASE_SERVICE_ROLE_KEY;
--   2. verify GET/HEAD readback; then
--   3. apply this revocation.
--
-- The Edge Function remains the public, parameter-free, sanitized status route.
-- No public/authenticated role can invoke the SECURITY DEFINER wrapper directly.

begin;

do $preflight$
begin
  if pg_catalog.to_regprocedure('public.chlom_mesh_public_status_v1()') is null then
    raise exception 'CHLOM mesh public status wrapper is absent; no changes applied'
      using errcode = '55000';
  end if;
end
$preflight$;

revoke execute on function public.chlom_mesh_public_status_v1()
  from public, anon, authenticated;
grant execute on function public.chlom_mesh_public_status_v1()
  to service_role, postgres;

commit;
