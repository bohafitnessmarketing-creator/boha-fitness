-- Funcionário "de todas as unidades" (manutenção, marketing…): unit = 'rede'.
--  * todo mundo que enxerga o Banco de funcionários vê essas pessoas (qualquer unidade);
--  * só administrador e marketing cadastram, editam e movem pessoas para 'rede' (gerente não mexe);
--  * ficam fora da Escala (a escala é por unidade).
alter table public.boha_employees drop constraint if exists boha_employees_unit_check;
alter table public.boha_employees add constraint boha_employees_unit_check check (unit in ('cb','te','ma','rede'));

drop policy if exists unit_scope on public.boha_employees;
drop policy if exists unit_scope_sel on public.boha_employees;
drop policy if exists unit_scope_ins on public.boha_employees;
drop policy if exists unit_scope_upd on public.boha_employees;
drop policy if exists unit_scope_del on public.boha_employees;
create policy unit_scope_sel on public.boha_employees as restrictive for select to authenticated
  using (unit = 'rede' or public.boha_unit_ok(unit));
create policy unit_scope_ins on public.boha_employees as restrictive for insert to authenticated
  with check (case when unit = 'rede' then public.boha_role() in ('admin','marketing') else public.boha_unit_ok(unit) end);
create policy unit_scope_upd on public.boha_employees as restrictive for update to authenticated
  using (case when unit = 'rede' then public.boha_role() in ('admin','marketing') else public.boha_unit_ok(unit) end)
  with check (case when unit = 'rede' then public.boha_role() in ('admin','marketing') else public.boha_unit_ok(unit) end);
create policy unit_scope_del on public.boha_employees as restrictive for delete to authenticated
  using (case when unit = 'rede' then public.boha_role() = 'admin' else public.boha_unit_ok(unit) end);

create or replace function public.boha_employee_list()
returns table(id uuid, unit text, name text, title text, permission_note text, collaborators_note text, status text, photo_path text, hub_access boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('funcionarios') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query
    select e.id,e.unit,e.name,e.title,e.permission_note,e.collaborators_note,e.status,e.photo_path,
      exists(select 1 from public.boha_access a where lower(a.name)=lower(e.name)) as hub_access
    from public.boha_employees e where e.unit = 'rede' or public.boha_unit_ok(e.unit)
    order by case e.unit when 'cb' then 1 when 'te' then 2 when 'ma' then 3 else 4 end,e.status,e.name;
end $$;

create or replace function public.boha_employee_options()
returns table(id uuid, name text, unit text, unit_label text, title text, photo_path text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.boha_can('checklist') or public.boha_can('hierarquia') or public.boha_can('marketing') or public.boha_can('qualidade') or public.boha_can('calendario') or public.boha_can('escalas') or public.boha_can('campanhas')) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  return query select e.id,e.name,e.unit,
    case e.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' when 'ma' then 'Macedônia' else 'Todas as unidades' end,e.title,e.photo_path
    from public.boha_employees e where e.status='active' and (e.unit = 'rede' or public.boha_unit_ok(e.unit))
    order by case e.unit when 'cb' then 1 when 'te' then 2 when 'ma' then 3 else 4 end,e.name;
end $$;
