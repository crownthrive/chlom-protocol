-- PentaBooks v1 -> PentaFabric production binding.
-- Applied to ThriveBase on 2026-08-26.
-- Routes remain fail-closed and do not manufacture provider-write, money-movement, or rights-grant authority.

insert into penta_runtime.agents_v1(
  agent_id,canonical_name,generation,role_slug,fabric_id,institutional_did,factory_did,parent_agent_id,
  authority_ceiling,decision_ceiling,execution_mode,independent_verifier_required,lifecycle_state,metadata,updated_at
) values (
  'ct.agent.gen61.penta.books','PentaBooks',61,'pentabooks','ct.fabric.penta.v1','did:chlom:agent:pentabooks',null,null,
  'A2','D2','candidate_only',true,'registered',
  jsonb_build_object('system_id','ct.pentabooks.v1','runtime','ThriveBase','version','1.0.0','source_policy','virality_work_project'),now()
) on conflict(agent_id) do update set canonical_name=excluded.canonical_name,generation=excluded.generation,role_slug=excluded.role_slug,
  fabric_id=excluded.fabric_id,institutional_did=excluded.institutional_did,authority_ceiling=excluded.authority_ceiling,
  decision_ceiling=excluded.decision_ceiling,execution_mode=excluded.execution_mode,independent_verifier_required=excluded.independent_verifier_required,
  lifecycle_state=excluded.lifecycle_state,metadata=penta_runtime.agents_v1.metadata || excluded.metadata,updated_at=now();

insert into penta_runtime.edges_v1(edge_id,source_id,target_id,edge_kind,route_state,authority_class,redundancy_group,fail_closed,provider_write,money_movement,rights_grant,source_ref,metadata,updated_at) values
('ct.penta.edge.chlom-to-pentabooks','ct.system.chlom.runtime','ct.agent.gen61.penta.books','control','controlled_test','D2','authority-routing',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('authority_inheritance',false,'rights_review_required',true),now()),
('ct.penta.edge.pentabooks-to-mesh','ct.agent.gen61.penta.books','ct.mesh.penta.v1','handoff','controlled_test','D1','institutional-routing',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('classification_required',true,'outbox','penta_book_events'),now()),
('ct.penta.edge.pentabooks-to-vault','ct.agent.gen61.penta.books','ct.agent.gen61.penta.vault','vault','controlled_test','D2','custody',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('sealed_material_fail_closed',true,'raw_secrets_allowed',false),now()),
('ct.penta.edge.pentabooks-to-verifier','ct.agent.gen61.penta.books','ct.agent.gen61.penta.verifier','evidence','controlled_test','D2','quality',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('vm_book_001',true,'vm_book_002',true,'independent_verifier_required',true),now()),
('ct.penta.edge.pentabooks-to-release','ct.agent.gen61.penta.books','ct.agent.gen61.penta.release','handoff','controlled_test','D2','publishing',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('preflight_required',true,'silent_overwrite',false),now()),
('ct.penta.edge.pentabooks-to-continuity','ct.agent.gen61.penta.books','ct.agent.gen61.penta.continuity','continuity','controlled_test','D1','continuity',true,false,false,false,'ct.pentabooks.v1',jsonb_build_object('append_and_preserve',true),now())
on conflict(edge_id) do update set source_id=excluded.source_id,target_id=excluded.target_id,edge_kind=excluded.edge_kind,route_state=excluded.route_state,
  authority_class=excluded.authority_class,redundancy_group=excluded.redundancy_group,fail_closed=excluded.fail_closed,provider_write=excluded.provider_write,
  money_movement=excluded.money_movement,rights_grant=excluded.rights_grant,source_ref=excluded.source_ref,metadata=penta_runtime.edges_v1.metadata || excluded.metadata,updated_at=now();

insert into penta_runtime.asset_bindings_v1(asset_id,canonical_name,asset_kind,generation,proprietary,classification,institutional_did,vault_asset_id,repository_ref,content_sha256,lifecycle_state,owner_agent_id,verifier_agent_id,dail_required,metadata,updated_at) values
('ct.asset.pentabooks.control.v1','PentaBooks Control Runtime','edge_function',61,true,'internal','did:chlom:asset:pentabooks-control',null,'crownthrive1/chlom-protocol/services/pentabooks-v1/control.ts','62fa83b51a7a2f99bbe52095e0074014b48ae0a3b9c0fcca1079fef593d954fe','active','ct.agent.gen61.penta.books','ct.agent.gen61.penta.verifier',true,jsonb_build_object('supabase_slug','penta-books-control','jwt_required',true),now()),
('ct.asset.pentabooks.public.v1','PentaBooks Public Read Surface','edge_function',61,true,'public','did:chlom:asset:pentabooks-public',null,'crownthrive1/chlom-protocol/services/pentabooks-v1/public.ts','a0c196c62a6b8f2f6dbe612a9393b4d02dd89c800f2e11253c6afe3ae553e231','active','ct.agent.gen61.penta.books','ct.agent.gen61.penta.verifier',true,jsonb_build_object('supabase_slug','penta-books-public','read_only',true),now())
on conflict(asset_id) do update set canonical_name=excluded.canonical_name,asset_kind=excluded.asset_kind,generation=excluded.generation,proprietary=excluded.proprietary,
  classification=excluded.classification,institutional_did=excluded.institutional_did,repository_ref=excluded.repository_ref,content_sha256=excluded.content_sha256,
  lifecycle_state=excluded.lifecycle_state,owner_agent_id=excluded.owner_agent_id,verifier_agent_id=excluded.verifier_agent_id,dail_required=excluded.dail_required,
  metadata=penta_runtime.asset_bindings_v1.metadata || excluded.metadata,updated_at=now();
