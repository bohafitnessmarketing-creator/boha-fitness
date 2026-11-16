-- Módulo "Crescimento do Instagram": um registro por unidade e data de medição (preenchido toda semana).
create table if not exists public.boha_ig_weekly (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  ref_date date not null check (ref_date between date '2020-01-01' and date '2100-01-01'),
  followers integer not null check (followers between 0 and 100000000),
  views integer check (views between 0 and 2000000000),
  reach integer check (reach between 0 and 2000000000),
  interactions integer check (interactions between 0 and 2000000000),
  profile_visits integer check (profile_visits between 0 and 2000000000),
  link_clicks integer check (link_clicks between 0 and 2000000000),
  posts integer check (posts between 0 and 1000),
  stories integer check (stories between 0 and 1000),
  note text not null default '' check (char_length(note) <= 200),
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit, ref_date)
);
create index if not exists boha_ig_weekly_unit_date on public.boha_ig_weekly(unit, ref_date);
alter table public.boha_ig_weekly enable row level security;
revoke all on public.boha_ig_weekly from anon;
grant select, insert, update, delete on public.boha_ig_weekly to authenticated;
drop policy if exists ig_weekly_access on public.boha_ig_weekly;
create policy ig_weekly_access on public.boha_ig_weekly for all to authenticated
  using (public.boha_can('instagram')) with check (public.boha_can('instagram'));
create or replace function public.boha_ig_stamp() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := coalesce(lower(auth.jwt()->>'email'), new.updated_by); return new; end $$;
drop trigger if exists boha_ig_stamp on public.boha_ig_weekly;
create trigger boha_ig_stamp before insert or update on public.boha_ig_weekly for each row execute function public.boha_ig_stamp();

-- O módulo "instagram" entra na lista de permissões por perfil.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
-- Ponto de partida: gerente e marketing registram as métricas. O administrador ajusta em Gestão de acessos.
update public.boha_role_modules set modules = array_append(modules,'instagram')
  where role in ('gerente','marketing') and not ('instagram' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Crescimento do Instagram',
  'Registre uma vez por semana os números do Instagram de cada unidade (seguidores, alcance, interações…) e acompanhe, em gráficos por mês e por ano, se a conta cresceu ou caiu.',
  'instagram',array['admin','gerente','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Crescimento do Instagram');
