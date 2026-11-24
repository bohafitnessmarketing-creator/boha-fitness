-- Módulo "Escalas e rotina": escala semanal por funcionário, modelos de rotina e checklist diário por unidade.
create table if not exists public.boha_shifts (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.boha_employees(id) on delete cascade,
  work_date date not null check (work_date between date '2020-01-01' and date '2100-01-01'),
  kind text not null check (kind in ('manha','tarde','noite','integral','folga','ferias','ausente')),
  start_time time,
  end_time time,
  note text not null default '' check (char_length(note) <= 120),
  updated_by text,
  updated_at timestamptz not null default now(),
  unique (employee_id, work_date)
);
create index if not exists boha_shifts_date on public.boha_shifts(work_date);

create table if not exists public.boha_routines (
  id uuid primary key default gen_random_uuid(),
  unit text check (unit is null or unit in ('cb','te','ma')),
  role_name text not null check (role_name in ('Recepção','Musculação','Aulas coletivas','Limpeza','Gerência','Todos')),
  moment text not null check (moment in ('abertura','manha','tarde','noite','fechamento')),
  title text not null check (char_length(title) between 1 and 160),
  weekdays smallint[] check (weekdays is null or (cardinality(weekdays) between 1 and 7 and weekdays <@ array[0,1,2,3,4,5,6]::smallint[])),
  sort integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.boha_routine_checks (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.boha_routines(id) on delete cascade,
  unit text not null check (unit in ('cb','te','ma')),
  check_date date not null check (check_date between date '2020-01-01' and date '2100-01-01'),
  done_by text,
  done_by_name text check (done_by_name is null or char_length(done_by_name) <= 80),
  done_at timestamptz not null default now(),
  unique (routine_id, unit, check_date)
);
create index if not exists boha_routine_checks_date on public.boha_routine_checks(check_date, unit);

create or replace function public.boha_shifts_stamp() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := coalesce(lower(auth.jwt()->>'email'), new.updated_by); return new; end $$;
drop trigger if exists boha_shifts_stamp on public.boha_shifts;
create trigger boha_shifts_stamp before insert or update on public.boha_shifts for each row execute function public.boha_shifts_stamp();
create or replace function public.boha_routine_checks_stamp() returns trigger language plpgsql as $$
begin new.done_by := coalesce(lower(auth.jwt()->>'email'), new.done_by); new.done_at := now(); return new; end $$;
drop trigger if exists boha_routine_checks_stamp on public.boha_routine_checks;
create trigger boha_routine_checks_stamp before insert on public.boha_routine_checks for each row execute function public.boha_routine_checks_stamp();

do $$ declare t text; begin
  foreach t in array array['boha_shifts','boha_routines','boha_routine_checks'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;
-- Quem tem o módulo vê tudo e marca a rotina do dia. Montar escala e rotina: administrador, dono, gerente e marketing.
drop policy if exists shifts_read on public.boha_shifts;
create policy shifts_read on public.boha_shifts for select to authenticated using (public.boha_can('escalas'));
drop policy if exists shifts_insert on public.boha_shifts;
create policy shifts_insert on public.boha_shifts for insert to authenticated
  with check (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']));
drop policy if exists shifts_update on public.boha_shifts;
create policy shifts_update on public.boha_shifts for update to authenticated
  using (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']))
  with check (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']));
drop policy if exists shifts_delete on public.boha_shifts;
create policy shifts_delete on public.boha_shifts for delete to authenticated
  using (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']));
drop policy if exists routines_read on public.boha_routines;
create policy routines_read on public.boha_routines for select to authenticated using (public.boha_can('escalas'));
drop policy if exists routines_write on public.boha_routines;
create policy routines_write on public.boha_routines for all to authenticated
  using (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']))
  with check (public.boha_can('escalas') and public.boha_role() = any (array['admin','dono','gerente','marketing']));
drop policy if exists checks_access on public.boha_routine_checks;
create policy checks_access on public.boha_routine_checks for all to authenticated
  using (public.boha_can('escalas')) with check (public.boha_can('escalas'));

-- A lista de funcionários (nome, unidade, cargo) também serve a quem tem o módulo "escalas".
do $$ declare def text; begin
  select pg_get_functiondef(p.oid) into def from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='boha_employee_options';
  if def is not null and position('boha_can(''escalas'')' in def) = 0 then
    def := replace(def, 'public.boha_can(''calendario''))', 'public.boha_can(''calendario'') or public.boha_can(''escalas'') or public.boha_can(''campanhas''))');
    execute def;
  end if;
end $$;

-- O módulo "escalas" entra na lista de permissões por perfil.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'escalas')
  where role in ('gerente','marketing') and not ('escalas' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Escalas e rotina',
  'Monte a escala semanal de cada unidade, veja quem trabalha hoje e acompanhe a rotina do dia (abertura, durante e fechamento) com checklist por unidade.',
  'escalas',array['admin','gerente','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Escalas e rotina');
