create table if not exists public.boha_employees (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  name text not null check (length(name) between 1 and 160),
  title text not null default '' check (length(title) <= 120),
  permission_note text not null default '' check (length(permission_note) <= 160),
  collaborators_note text not null default '' check (length(collaborators_note) <= 400),
  status text not null default 'active' check (status in ('active','former')),
  photo_path text,
  source_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit, name)
);
create index if not exists boha_employees_active_unit_name on public.boha_employees(unit,name) where status='active';
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public,anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
alter table public.boha_employees enable row level security;
revoke all on public.boha_employees from anon;
grant select, insert, update, delete on public.boha_employees to authenticated;
drop policy if exists employees_read on public.boha_employees;
create policy employees_read on public.boha_employees for select to authenticated using (public.boha_can('funcionarios'));
drop policy if exists employees_admin_write on public.boha_employees;
create policy employees_admin_write on public.boha_employees for all to authenticated using (public.boha_is_admin()) with check (public.boha_is_admin());

create or replace function public.boha_employee_list()
returns table(id uuid,unit text,name text,title text,permission_note text,collaborators_note text,status text,photo_path text,hub_access boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('funcionarios') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query
    select e.id,e.unit,e.name,e.title,e.permission_note,e.collaborators_note,e.status,e.photo_path,
      exists(select 1 from public.boha_access a where lower(a.name)=lower(e.name)) as hub_access
    from public.boha_employees e order by case e.unit when 'cb' then 1 when 'te' then 2 else 3 end,e.status,e.name;
end $$;
revoke all on function public.boha_employee_list() from public,anon;
grant execute on function public.boha_employee_list() to authenticated;

create or replace function public.boha_employee_options()
returns table(id uuid,name text,unit text,unit_label text,title text,photo_path text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.boha_can('checklist') or public.boha_can('hierarquia') or public.boha_can('marketing') or public.boha_can('qualidade') or public.boha_can('calendario')) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  return query select e.id,e.name,e.unit,
    case e.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' else 'Macedônia' end,e.title,e.photo_path
    from public.boha_employees e where e.status='active'
    order by case e.unit when 'cb' then 1 when 'te' then 2 else 3 end,e.name;
end $$;
revoke all on function public.boha_employee_options() from public,anon;
grant execute on function public.boha_employee_options() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('boha-employees','boha-employees',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists employees_photo_read on storage.objects;
create policy employees_photo_read on storage.objects for select to authenticated using (bucket_id='boha-employees' and (public.boha_can('funcionarios') or public.boha_can('hierarquia') or public.boha_can('checklist') or public.boha_can('marketing') or public.boha_can('qualidade')));
drop policy if exists employees_photo_write on storage.objects;
create policy employees_photo_write on storage.objects for all to authenticated using (bucket_id='boha-employees' and public.boha_is_admin()) with check (bucket_id='boha-employees' and public.boha_is_admin());

alter table public.boha_tasks add column if not exists employee_id uuid references public.boha_employees(id) on delete set null;
alter table public.boha_professor_ratings add column if not exists employee_id uuid references public.boha_employees(id) on delete set null;
create table if not exists public.boha_class_instructors (
  schedule_id uuid not null references public.boha_class_schedule(id) on delete cascade,
  employee_id uuid not null references public.boha_employees(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(schedule_id,employee_id)
);
alter table public.boha_class_instructors enable row level security;
revoke all on public.boha_class_instructors from anon;
grant select,insert,delete on public.boha_class_instructors to authenticated;
drop policy if exists class_instructors_read on public.boha_class_instructors;
create policy class_instructors_read on public.boha_class_instructors for select to authenticated using (public.boha_can('marketing'));
drop policy if exists class_instructors_write on public.boha_class_instructors;
create policy class_instructors_write on public.boha_class_instructors for all to authenticated using (public.boha_can('marketing')) with check (public.boha_can('marketing'));
drop policy if exists class_postings_insert on public.boha_class_postings;
create policy class_postings_insert on public.boha_class_postings for insert to authenticated with check (public.boha_can('marketing'));
drop policy if exists class_postings_update on public.boha_class_postings;
create policy class_postings_update on public.boha_class_postings for update to authenticated using (public.boha_can('marketing')) with check (public.boha_can('marketing'));

create table if not exists public.boha_editorial_items (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  planned_date date not null,
  channel text not null default 'Instagram' check (length(channel) between 1 and 40),
  title text not null check (length(title) between 1 and 160),
  caption text not null default '' check (length(caption) <= 3000),
  status text not null default 'idea' check (status in ('idea','scheduled','published')),
  employee_id uuid references public.boha_employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists boha_editorial_items_date on public.boha_editorial_items(unit,planned_date);
alter table public.boha_editorial_items enable row level security;
revoke all on public.boha_editorial_items from anon;
grant select,insert,update,delete on public.boha_editorial_items to authenticated;
drop policy if exists editorial_module_access on public.boha_editorial_items;
create policy editorial_module_access on public.boha_editorial_items for all to authenticated using (public.boha_can('calendario')) with check (public.boha_can('calendario'));

create table if not exists public.boha_nps_responses (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  score integer not null check (score between 0 and 10),
  feedback text not null default '' check (length(feedback) <= 2000),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
create index if not exists boha_nps_responses_unit_date on public.boha_nps_responses(unit,created_at desc);
alter table public.boha_nps_responses enable row level security;
revoke all on public.boha_nps_responses from anon;
grant select,insert,update,delete on public.boha_nps_responses to authenticated;
drop policy if exists nps_module_access on public.boha_nps_responses;
create policy nps_module_access on public.boha_nps_responses for all to authenticated using (public.boha_can('nps')) with check (public.boha_can('nps'));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Banco de funcionários liberado',
  'O cadastro reúne a equipe por unidade, mantém ex-funcionários no histórico e permite atualizar cargo e foto. Você também pode liberar o módulo para outros perfis em Gestão de acessos.',
  'funcionarios',array['admin'],'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Banco de funcionários liberado');
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Funcionários ativos nos módulos',
  'No A fazer, escolha com quem precisa conversar. Na grade de aulas coletivas, atribua o professor em cada horário; ex-funcionários não aparecem nessas opções.',
  null,null,'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Funcionários ativos nos módulos');
