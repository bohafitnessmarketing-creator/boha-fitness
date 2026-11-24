-- "Rotina" vira um módulo próprio, separado de "Escalas". Escalas = quem trabalha quando; Rotina = o que se faz todo dia.
drop policy if exists routines_read on public.boha_routines;
create policy routines_read on public.boha_routines for select to authenticated using (public.boha_can('rotina'));
drop policy if exists routines_write on public.boha_routines;
create policy routines_write on public.boha_routines for all to authenticated
  using (public.boha_can('rotina') and public.boha_role() = any (array['admin','dono','gerente','marketing']))
  with check (public.boha_can('rotina') and public.boha_role() = any (array['admin','dono','gerente','marketing']));
drop policy if exists checks_access on public.boha_routine_checks;
create policy checks_access on public.boha_routine_checks for all to authenticated
  using (public.boha_can('rotina')) with check (public.boha_can('rotina'));

alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
-- Quem já tinha "escalas" (módulo único até agora) continua vendo a rotina.
update public.boha_role_modules set modules = array_append(modules,'rotina')
  where 'escalas' = any(modules) and not ('rotina' = any(modules));

update public.boha_notices set title='Novo: Escalas',
  body='Monte a escala semanal de cada unidade, veja quem trabalha hoje em cada turno e acompanhe as horas e a cobertura da semana.'
  where title='Novo: Escalas e rotina';
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Rotina',
  'A rotina de cada função (abertura, durante o dia e fechamento) com checklist diário por unidade e o % cumprido nos últimos 7 dias.',
  'rotina',array['admin','gerente','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Rotina');
