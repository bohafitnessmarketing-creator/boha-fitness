-- Perfis por área. Os perfis antigos permanecem aceitos até que a gestão os reclassifique.
alter table public.boha_access drop constraint if exists boha_access_role_check;
alter table public.boha_access add constraint boha_access_role_check
  check (role in ('admin','dono','gerente','marketing','recepcao','editor','viewer'));

create or replace function public.boha_can(p_module text) returns boolean
language sql stable security definer set search_path = '' as $$
  select case public.boha_role()
    when 'admin' then true
    when 'dono' then p_module in ('hierarquia','resultados','compras')
    when 'gerente' then p_module in ('hierarquia','resultados','compras','checklist')
    when 'marketing' then p_module = 'marketing'
    when 'recepcao' then p_module in ('hierarquia','checklist','manuais')
    when 'editor' then p_module in ('hierarquia','compras','checklist')
    when 'viewer' then p_module in ('hierarquia','compras','checklist')
    else false end
$$;

create or replace function public.boha_access_save(p_email text, p_name text, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
        v_me text := lower(auth.jwt()->>'email');
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido.'; end if;
  if p_role is null or p_role not in ('admin','dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if v_email = v_me and p_role <> 'admin' then raise exception 'Você não pode tirar o seu próprio acesso de administrador.'; end if;
  insert into public.boha_access(email,name,role)
  values(v_email,nullif(left(trim(coalesce(p_name,'')),60),''),p_role)
  on conflict(email) do update set role=excluded.role,name=coalesce(excluded.name,public.boha_access.name);
end $$;

-- Permissões reais no banco, além da navegação no Hub.
drop policy if exists content_read on public.boha_content;
create policy content_read on public.boha_content for select to authenticated using (public.boha_can('hierarquia'));

drop policy if exists member_read on public.boha_members;
drop policy if exists member_insert on public.boha_members;
drop policy if exists member_update on public.boha_members;
create policy member_read on public.boha_members for select to authenticated using (public.boha_can('hierarquia'));
create policy member_insert on public.boha_members for insert to authenticated with check (public.boha_role() in ('admin','gerente','editor'));
create policy member_update on public.boha_members for update to authenticated using (public.boha_role() in ('admin','gerente','editor')) with check (public.boha_role() in ('admin','gerente','editor'));

drop policy if exists org_read on public.boha_org_nodes;
drop policy if exists org_ins on public.boha_org_nodes;
drop policy if exists org_del on public.boha_org_nodes;
create policy org_read on public.boha_org_nodes for select to authenticated using (public.boha_can('hierarquia'));
create policy org_ins on public.boha_org_nodes for insert to authenticated with check (public.boha_role() in ('admin','gerente','editor'));
create policy org_del on public.boha_org_nodes for delete to authenticated using (public.boha_role() in ('admin','gerente','editor'));

drop policy if exists evo_read on public.boha_evo;
drop policy if exists evo_insert on public.boha_evo;
drop policy if exists evo_update on public.boha_evo;
create policy evo_read on public.boha_evo for select to authenticated using (public.boha_can('resultados'));
create policy evo_insert on public.boha_evo for insert to authenticated with check (public.boha_role()='admin');
create policy evo_update on public.boha_evo for update to authenticated using (public.boha_role()='admin') with check (public.boha_role()='admin');
drop policy if exists evo_hist_read on public.boha_evo_history;
create policy evo_hist_read on public.boha_evo_history for select to authenticated using (public.boha_can('resultados'));

drop policy if exists areas_read on public.boha_areas;
drop policy if exists areas_write on public.boha_areas;
create policy areas_read on public.boha_areas for select to authenticated using (public.boha_can('compras'));
create policy areas_write on public.boha_areas for all to authenticated using (public.boha_role() in ('admin','dono','gerente','editor')) with check (public.boha_role() in ('admin','dono','gerente','editor'));
drop policy if exists req_read on public.boha_requests;
drop policy if exists req_insert on public.boha_requests;
drop policy if exists req_update on public.boha_requests;
drop policy if exists req_delete on public.boha_requests;
create policy req_read on public.boha_requests for select to authenticated using (public.boha_can('compras'));
create policy req_insert on public.boha_requests for insert to authenticated with check (public.boha_role() in ('admin','dono','gerente','editor'));
create policy req_update on public.boha_requests for update to authenticated using (public.boha_role() in ('admin','dono','gerente','editor')) with check (public.boha_role() in ('admin','dono','gerente','editor'));
create policy req_delete on public.boha_requests for delete to authenticated using (public.boha_role()='admin');

drop policy if exists tasks_own on public.boha_tasks;
create policy tasks_own on public.boha_tasks for all to authenticated
using (owner=lower(auth.jwt()->>'email') and public.boha_can('checklist'))
with check (owner=lower(auth.jwt()->>'email') and public.boha_can('checklist'));

drop policy if exists compras_img_read on storage.objects;
drop policy if exists compras_img_write on storage.objects;
drop policy if exists compras_img_update on storage.objects;
drop policy if exists compras_img_delete on storage.objects;
create policy compras_img_read on storage.objects for select to authenticated using (bucket_id='boha-compras' and public.boha_can('compras'));
create policy compras_img_write on storage.objects for insert to authenticated with check (bucket_id='boha-compras' and public.boha_role() in ('admin','dono','gerente','editor'));
create policy compras_img_update on storage.objects for update to authenticated using (bucket_id='boha-compras' and public.boha_role() in ('admin','dono','gerente','editor')) with check (bucket_id='boha-compras' and public.boha_role() in ('admin','dono','gerente','editor'));
create policy compras_img_delete on storage.objects for delete to authenticated using (bucket_id='boha-compras' and public.boha_role()='admin');
drop policy if exists photo_read on storage.objects;
drop policy if exists photo_insert on storage.objects;
drop policy if exists photo_update on storage.objects;
drop policy if exists photo_delete on storage.objects;
create policy photo_read on storage.objects for select to authenticated using (bucket_id='boha-photos' and public.boha_can('hierarquia'));
create policy photo_insert on storage.objects for insert to authenticated with check (bucket_id='boha-photos' and public.boha_role() in ('admin','gerente','editor'));
create policy photo_update on storage.objects for update to authenticated using (bucket_id='boha-photos' and public.boha_role() in ('admin','gerente','editor')) with check (bucket_id='boha-photos' and public.boha_role() in ('admin','gerente','editor'));
create policy photo_delete on storage.objects for delete to authenticated using (bucket_id='boha-photos' and public.boha_role() in ('admin','gerente','editor'));
