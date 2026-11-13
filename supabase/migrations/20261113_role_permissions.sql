create table if not exists public.boha_role_modules (
  role text primary key check (role in ('dono','gerente','marketing','recepcao','editor','viewer')),
  modules text[] not null default '{}',
  updated_at timestamptz not null default now(),
  constraint boha_role_modules_valid check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais']::text[])
);
insert into public.boha_role_modules(role,modules) values
 ('dono',array['hierarquia','resultados','compras']),
 ('gerente',array['hierarquia','resultados','compras','checklist']),
 ('marketing',array['marketing']),
 ('recepcao',array['hierarquia','checklist','manuais']),
 ('editor',array['hierarquia','compras','checklist']),
 ('viewer',array['hierarquia','compras','checklist'])
on conflict (role) do nothing;
alter table public.boha_role_modules enable row level security;
revoke all on public.boha_role_modules from anon;
grant select on public.boha_role_modules to authenticated;
drop policy if exists role_modules_read on public.boha_role_modules;
create policy role_modules_read on public.boha_role_modules for select to authenticated using (public.boha_role() is not null);

create or replace function public.boha_can(p_module text) returns boolean
language sql stable security definer set search_path = '' as $$
  select case when public.boha_role() = 'admin' then true
    when p_module = 'acessos' then false
    else coalesce((select p_module = any(modules) from public.boha_role_modules where role = public.boha_role()), false)
  end
$$;

create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at) values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;

drop policy if exists professor_ratings_admin_read on public.boha_professor_ratings;
create policy professor_ratings_admin_read on public.boha_professor_ratings for select to authenticated using (public.boha_can('qualidade'));
drop policy if exists professor_photo_read on storage.objects;
create policy professor_photo_read on storage.objects for select to authenticated using (bucket_id='boha-professores' and public.boha_can('qualidade'));

create policy content_module_guard on public.boha_content as restrictive for all to authenticated using (public.boha_can('hierarquia')) with check (public.boha_can('hierarquia'));
create policy members_module_guard on public.boha_members as restrictive for all to authenticated using (public.boha_can('hierarquia')) with check (public.boha_can('hierarquia'));
create policy org_module_guard on public.boha_org_nodes as restrictive for all to authenticated using (public.boha_can('hierarquia')) with check (public.boha_can('hierarquia'));
create policy evo_module_guard on public.boha_evo as restrictive for all to authenticated using (public.boha_can('resultados')) with check (public.boha_can('resultados'));
create policy evo_history_module_guard on public.boha_evo_history as restrictive for all to authenticated using (public.boha_can('resultados')) with check (public.boha_can('resultados'));
create policy requests_module_guard on public.boha_requests as restrictive for all to authenticated using (public.boha_can('compras')) with check (public.boha_can('compras'));
create policy areas_module_guard on public.boha_areas as restrictive for all to authenticated using (public.boha_can('compras')) with check (public.boha_can('compras'));
create policy professor_module_guard on public.boha_professor_ratings as restrictive for all to authenticated using (public.boha_can('qualidade')) with check (public.boha_can('qualidade'));
create policy postings_module_guard on public.boha_class_postings as restrictive for all to authenticated using (public.boha_can('marketing')) with check (public.boha_can('marketing'));
create policy schedule_module_guard on public.boha_class_schedule as restrictive for all to authenticated using (public.boha_can('marketing')) with check (public.boha_can('marketing'));
create policy boha_storage_module_guard on storage.objects as restrictive for all to authenticated
 using (case bucket_id when 'boha-photos' then public.boha_can('hierarquia') when 'boha-compras' then public.boha_can('compras') when 'boha-professores' then public.boha_can('qualidade') else true end)
 with check (case bucket_id when 'boha-photos' then public.boha_can('hierarquia') when 'boha-compras' then public.boha_can('compras') when 'boha-professores' then public.boha_can('qualidade') else true end);
