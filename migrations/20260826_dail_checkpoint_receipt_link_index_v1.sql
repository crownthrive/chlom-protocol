-- Cover the append-only checkpoint receipt-chain foreign key.
--
-- The assurance tables remain fail-closed and append-only. This migration adds
-- no data route and does not change the institutional Phase-4 activation state.

begin;

do $preflight$
begin
  if pg_catalog.to_regclass(
       'chlom_runtime.dail_cold_checkpoints_v1'
     ) is null then
    raise exception 'DAIL cold checkpoint table is absent; no changes applied'
      using errcode = '55000';
  end if;
end
$preflight$;

create index if not exists dail_cold_checkpoints_previous_receipt_v1_idx
  on chlom_runtime.dail_cold_checkpoints_v1 (
    previous_checkpoint_receipt_sha256
  )
  where previous_checkpoint_receipt_sha256 is not null;

commit;
