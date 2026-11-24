-- Gerente pode editar a Hierarquia, mas só a da própria unidade.
-- Antes o banco aceitava gravação de gerente sem olhar a unidade. Agora, para o gerente:
--   * só mexe em pessoas/posições da unidade dele (ids "ma-…", "cb-…", "te-…" ou posições extras criadas nela);
--   * não mexe nos cargos da rede (diretoria, financeiro, RH, campanhas…);
--   * gerente sem unidade definida não grava nada.
-- Administrador, editor e marketing continuam como estavam.

create or replace function public.boha_hier_ok(p_id text, p_scope text default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when public.boha_role() is distinct from 'gerente' then true
    else coalesce((
      select a.unit is not null and (
               (p_scope is not null and p_scope = a.unit)
            or (p_scope is null and (p_id like a.unit || '-%'
                 or exists (select 1 from public.boha_org_nodes n where n.id = p_id and n.op = 'add' and n.scope = a.unit))))
        from public.boha_access a where a.email = lower(auth.jwt()->>'email')), false)
  end
$$;
revoke all on function public.boha_hier_ok(text, text) from public, anon;
grant execute on function public.boha_hier_ok(text, text) to authenticated;

-- Organograma: adicionar/ocultar/excluir posição
drop policy if exists hier_scope_org_ins on public.boha_org_nodes;
create policy hier_scope_org_ins on public.boha_org_nodes as restrictive for insert to authenticated
  with check (public.boha_hier_ok(id, case when op = 'add' then scope else null end));
drop policy if exists hier_scope_org_del on public.boha_org_nodes;
create policy hier_scope_org_del on public.boha_org_nodes as restrictive for delete to authenticated
  using (public.boha_hier_ok(id, case when op = 'add' then scope else null end));

-- Nomes e anotações das pessoas
drop policy if exists hier_scope_mem_ins on public.boha_members;
create policy hier_scope_mem_ins on public.boha_members as restrictive for insert to authenticated
  with check (public.boha_hier_ok(id));
drop policy if exists hier_scope_mem_upd on public.boha_members;
create policy hier_scope_mem_upd on public.boha_members as restrictive for update to authenticated
  using (public.boha_hier_ok(id)) with check (public.boha_hier_ok(id));

-- Fotos (arquivo "<id>.jpg" no bucket boha-photos)
drop policy if exists hier_scope_photo_ins on storage.objects;
create policy hier_scope_photo_ins on storage.objects as restrictive for insert to authenticated
  with check (bucket_id <> 'boha-photos' or public.boha_hier_ok(regexp_replace(name, '\.jpg$', ''), null));
drop policy if exists hier_scope_photo_upd on storage.objects;
create policy hier_scope_photo_upd on storage.objects as restrictive for update to authenticated
  using (bucket_id <> 'boha-photos' or public.boha_hier_ok(regexp_replace(name, '\.jpg$', ''), null))
  with check (bucket_id <> 'boha-photos' or public.boha_hier_ok(regexp_replace(name, '\.jpg$', ''), null));
drop policy if exists hier_scope_photo_del on storage.objects;
create policy hier_scope_photo_del on storage.objects as restrictive for delete to authenticated
  using (bucket_id <> 'boha-photos' or public.boha_hier_ok(regexp_replace(name, '\.jpg$', ''), null));
