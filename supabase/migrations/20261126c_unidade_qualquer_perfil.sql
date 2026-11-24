-- A unidade pode ser atribuída a qualquer perfil, menos administrador (que sempre vê tudo).
-- Gerente e recepção continuam exigindo unidade; dono e marketing podem ter unidade ou ficar com a rede toda.
create or replace function public.boha_access_save(p_email text, p_name text, p_role text, p_unit text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
        v_me text := lower(auth.jwt()->>'email');
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido.'; end if;
  if p_role is null or p_role not in ('admin','dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_unit is not null and p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  if v_email = v_me and p_role <> 'admin' then raise exception 'Você não pode tirar o seu próprio acesso de administrador.'; end if;
  insert into public.boha_access(email,name,role,unit)
  values(v_email,nullif(left(trim(coalesce(p_name,'')),60),''),p_role,case when p_role <> 'admin' then p_unit end)
  on conflict(email) do update set role=excluded.role,name=coalesce(excluded.name,public.boha_access.name),
    unit=case when excluded.role = 'admin' then null else coalesce(excluded.unit,public.boha_access.unit) end;
end $$;
revoke all on function public.boha_access_save(text,text,text,text) from public, anon;
grant execute on function public.boha_access_save(text,text,text,text) to authenticated;

create or replace function public.boha_access_set_unit(p_email text, p_unit text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if p_unit is not null and p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  update public.boha_access set unit = p_unit where email = v_email and role <> 'admin';
  if not found then raise exception 'Administrador sempre vê todas as unidades.'; end if;
end $$;
revoke all on function public.boha_access_set_unit(text,text) from public, anon;
grant execute on function public.boha_access_set_unit(text,text) to authenticated;
