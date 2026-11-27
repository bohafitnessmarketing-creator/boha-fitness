-- Professores de aulas coletivas: quais modalidades dão aula (uma ou mais). Lista = modalidades do site (+ texto livre).
alter table public.boha_employees add column if not exists modalities text[] not null default '{}'
  check (cardinality(modalities) <= 12);

drop function if exists public.boha_employee_list();
create function public.boha_employee_list()
returns table(id uuid, unit text, name text, title text, permission_note text, collaborators_note text, status text, photo_path text, hub_access boolean, modalities text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('funcionarios') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query
    select e.id,e.unit,e.name,e.title,e.permission_note,e.collaborators_note,e.status,e.photo_path,
      exists(select 1 from public.boha_access a where lower(a.name)=lower(e.name)) as hub_access, e.modalities
    from public.boha_employees e where e.unit = 'rede' or public.boha_unit_ok(e.unit)
    order by case e.unit when 'cb' then 1 when 'te' then 2 when 'ma' then 3 else 4 end,e.status,e.name;
end $$;
revoke all on function public.boha_employee_list() from public, anon;
grant execute on function public.boha_employee_list() to authenticated;

drop function if exists public.boha_employee_options();
create function public.boha_employee_options()
returns table(id uuid, name text, unit text, unit_label text, title text, photo_path text, modalities text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.boha_can('checklist') or public.boha_can('hierarquia') or public.boha_can('marketing') or public.boha_can('qualidade') or public.boha_can('calendario') or public.boha_can('escalas') or public.boha_can('campanhas')) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  return query select e.id,e.name,e.unit,
    case e.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' when 'ma' then 'Macedônia' else 'Todas as unidades' end,e.title,e.photo_path,e.modalities
    from public.boha_employees e where e.status='active' and (e.unit = 'rede' or public.boha_unit_ok(e.unit))
    order by case e.unit when 'cb' then 1 when 'te' then 2 when 'ma' then 3 else 4 end,e.name;
end $$;
revoke all on function public.boha_employee_options() from public, anon;
grant execute on function public.boha_employee_options() to authenticated;
