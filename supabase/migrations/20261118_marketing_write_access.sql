-- Perfil Marketing passa a poder ALTERAR (e não só ver) Hierarquia, Banco de funcionários,
-- Compras & Manutenção e Qualidade dos professores; NPS ganha correção/exclusão.
-- Regra de segurança: EXCLUIR dados de resultado (pedidos, avaliações, funcionários) continua só com o administrador.

-- 1) Compras & Manutenção entra nos módulos do Marketing
update public.boha_role_modules set modules = array_append(modules,'compras')
  where role = 'marketing' and not ('compras' = any(modules));

-- 2) Hierarquia (membros, organograma e fotos)
drop policy if exists member_insert on public.boha_members;
create policy member_insert on public.boha_members for insert to authenticated
  with check (public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists member_update on public.boha_members;
create policy member_update on public.boha_members for update to authenticated
  using (public.boha_role() = any (array['admin','gerente','editor','marketing']))
  with check (public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists org_ins on public.boha_org_nodes;
create policy org_ins on public.boha_org_nodes for insert to authenticated
  with check (public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists org_del on public.boha_org_nodes;
create policy org_del on public.boha_org_nodes for delete to authenticated
  using (public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists photo_insert on storage.objects;
create policy photo_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'boha-photos' and public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists photo_update on storage.objects;
create policy photo_update on storage.objects for update to authenticated
  using (bucket_id = 'boha-photos' and public.boha_role() = any (array['admin','gerente','editor','marketing']))
  with check (bucket_id = 'boha-photos' and public.boha_role() = any (array['admin','gerente','editor','marketing']));
drop policy if exists photo_delete on storage.objects;
create policy photo_delete on storage.objects for delete to authenticated
  using (bucket_id = 'boha-photos' and public.boha_role() = any (array['admin','gerente','editor','marketing']));

-- 3) Banco de funcionários: marketing cadastra e edita (não exclui) e cuida das fotos
drop policy if exists employees_marketing_insert on public.boha_employees;
create policy employees_marketing_insert on public.boha_employees for insert to authenticated
  with check (public.boha_role() = 'marketing' and public.boha_can('funcionarios'));
drop policy if exists employees_marketing_update on public.boha_employees;
create policy employees_marketing_update on public.boha_employees for update to authenticated
  using (public.boha_role() = 'marketing' and public.boha_can('funcionarios'))
  with check (public.boha_role() = 'marketing' and public.boha_can('funcionarios'));
drop policy if exists employees_photo_marketing on storage.objects;
create policy employees_photo_marketing on storage.objects for all to authenticated
  using (bucket_id = 'boha-employees' and public.boha_role() = 'marketing' and public.boha_can('funcionarios'))
  with check (bucket_id = 'boha-employees' and public.boha_role() = 'marketing' and public.boha_can('funcionarios'));

-- 4) Compras & Manutenção: marketing abre e edita pedidos, áreas e fotos (exclusão segue só admin)
drop policy if exists areas_write on public.boha_areas;
create policy areas_write on public.boha_areas for all to authenticated
  using (public.boha_role() = any (array['admin','dono','gerente','editor','marketing']))
  with check (public.boha_role() = any (array['admin','dono','gerente','editor','marketing']));
drop policy if exists req_insert on public.boha_requests;
create policy req_insert on public.boha_requests for insert to authenticated
  with check (public.boha_role() = any (array['admin','dono','gerente','editor','marketing']));
drop policy if exists req_update on public.boha_requests;
create policy req_update on public.boha_requests for update to authenticated
  using (public.boha_role() = any (array['admin','dono','gerente','editor','marketing']))
  with check (public.boha_role() = any (array['admin','dono','gerente','editor','marketing']));
drop policy if exists compras_img_write on storage.objects;
create policy compras_img_write on storage.objects for insert to authenticated
  with check (bucket_id = 'boha-compras' and public.boha_role() = any (array['admin','dono','gerente','editor','marketing']));
drop policy if exists compras_img_update on storage.objects;
create policy compras_img_update on storage.objects for update to authenticated
  using (bucket_id = 'boha-compras' and public.boha_role() = any (array['admin','dono','gerente','editor','marketing']))
  with check (bucket_id = 'boha-compras' and public.boha_role() = any (array['admin','dono','gerente','editor','marketing']));

-- 5) Qualidade dos professores: marketing lança e corrige avaliações e cuida das fotos (exclusão de avaliação segue só admin)
drop policy if exists professor_ratings_admin_insert on public.boha_professor_ratings;
create policy professor_ratings_admin_insert on public.boha_professor_ratings for insert to authenticated
  with check (public.boha_role() = any (array['admin','marketing']));
drop policy if exists professor_ratings_admin_update on public.boha_professor_ratings;
create policy professor_ratings_admin_update on public.boha_professor_ratings for update to authenticated
  using (public.boha_role() = any (array['admin','marketing']))
  with check (public.boha_role() = any (array['admin','marketing']));
drop policy if exists professor_photo_insert on storage.objects;
create policy professor_photo_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'boha-professores' and public.boha_role() = any (array['admin','marketing']));
drop policy if exists professor_photo_update on storage.objects;
create policy professor_photo_update on storage.objects for update to authenticated
  using (bucket_id = 'boha-professores' and public.boha_role() = any (array['admin','marketing']))
  with check (bucket_id = 'boha-professores' and public.boha_role() = any (array['admin','marketing']));
drop policy if exists professor_photo_delete on storage.objects;
create policy professor_photo_delete on storage.objects for delete to authenticated
  using (bucket_id = 'boha-professores' and public.boha_role() = any (array['admin','marketing']));

-- 6) Pesquisa de NPS: marketing também corrige e exclui respostas lançadas por engano
drop policy if exists nps_admin_update on public.boha_nps_responses;
create policy nps_admin_update on public.boha_nps_responses for update to authenticated
  using (public.boha_role() = any (array['admin','marketing']) and public.boha_can('nps'))
  with check (public.boha_role() = any (array['admin','marketing']) and public.boha_can('nps'));
drop policy if exists nps_admin_delete on public.boha_nps_responses;
create policy nps_admin_delete on public.boha_nps_responses for delete to authenticated
  using (public.boha_role() = any (array['admin','marketing']) and public.boha_can('nps'));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Marketing agora pode alterar mais módulos',
  'O perfil Marketing passou a poder editar a Hierarquia, o Banco de funcionários, Compras & Manutenção e a Qualidade dos professores (lançar avaliações e fotos), além de corrigir respostas do NPS. Excluir pedidos, avaliações e funcionários continua só com o administrador.',
  null,array['admin','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Marketing agora pode alterar mais módulos');
