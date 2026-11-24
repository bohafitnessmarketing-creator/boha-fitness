-- Gerente edita as informações dos módulos que tem liberados. A trava por unidade (política restritiva
-- unit_scope) continua valendo: o gerente só altera dados da própria unidade. Exclusões seguem só com o administrador.

-- Resultados (indicadores mensais da unidade)
drop policy if exists evo_gerente_insert on public.boha_evo;
create policy evo_gerente_insert on public.boha_evo for insert to authenticated
  with check (public.boha_role() = 'gerente' and public.boha_can('resultados'));
drop policy if exists evo_gerente_update on public.boha_evo;
create policy evo_gerente_update on public.boha_evo for update to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('resultados'))
  with check (public.boha_role() = 'gerente' and public.boha_can('resultados'));

-- Banco de funcionários (cadastro e edição; sem exclusão)
drop policy if exists employees_gerente_insert on public.boha_employees;
create policy employees_gerente_insert on public.boha_employees for insert to authenticated
  with check (public.boha_role() = 'gerente' and public.boha_can('funcionarios'));
drop policy if exists employees_gerente_update on public.boha_employees;
create policy employees_gerente_update on public.boha_employees for update to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('funcionarios'))
  with check (public.boha_role() = 'gerente' and public.boha_can('funcionarios'));
drop policy if exists employees_photo_gerente on storage.objects;
create policy employees_photo_gerente on storage.objects for all to authenticated
  using (bucket_id = 'boha-employees' and public.boha_role() = 'gerente' and public.boha_can('funcionarios'))
  with check (bucket_id = 'boha-employees' and public.boha_role() = 'gerente' and public.boha_can('funcionarios'));

-- Qualidade dos professores
drop policy if exists professor_ratings_gerente_insert on public.boha_professor_ratings;
create policy professor_ratings_gerente_insert on public.boha_professor_ratings for insert to authenticated
  with check (public.boha_role() = 'gerente' and public.boha_can('qualidade'));
drop policy if exists professor_ratings_gerente_update on public.boha_professor_ratings;
create policy professor_ratings_gerente_update on public.boha_professor_ratings for update to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('qualidade'))
  with check (public.boha_role() = 'gerente' and public.boha_can('qualidade'));
drop policy if exists professor_photo_gerente_insert on storage.objects;
create policy professor_photo_gerente_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'boha-professores' and public.boha_role() = 'gerente' and public.boha_can('qualidade'));
drop policy if exists professor_photo_gerente_update on storage.objects;
create policy professor_photo_gerente_update on storage.objects for update to authenticated
  using (bucket_id = 'boha-professores' and public.boha_role() = 'gerente' and public.boha_can('qualidade'))
  with check (bucket_id = 'boha-professores' and public.boha_role() = 'gerente' and public.boha_can('qualidade'));

-- Pesquisa NPS: corrigir e excluir respostas lançadas por engano
drop policy if exists nps_gerente_update on public.boha_nps_responses;
create policy nps_gerente_update on public.boha_nps_responses for update to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('nps'))
  with check (public.boha_role() = 'gerente' and public.boha_can('nps'));
drop policy if exists nps_gerente_delete on public.boha_nps_responses;
create policy nps_gerente_delete on public.boha_nps_responses for delete to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('nps'));
