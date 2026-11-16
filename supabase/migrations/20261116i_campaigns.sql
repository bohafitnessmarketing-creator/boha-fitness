-- Módulo "Campanhas": campanha do mês, funil de vendas, ideias e balanço.
create table if not exists public.boha_campaigns (
  id uuid primary key default gen_random_uuid(),
  month date not null unique check (month = (date_trunc('month', month))::date),
  name text not null check (char_length(name) between 1 and 120),
  objective text not null default '' check (char_length(objective) <= 400),
  offer text not null default '' check (char_length(offer) <= 400),
  audience text not null default '' check (char_length(audience) <= 300),
  channels text[] not null default '{}'::text[]
    check (channels <@ array['Instagram','WhatsApp','Tráfego pago','Indicação','Panfleto / rua','Parcerias','Evento na unidade']::text[]),
  start_date date,
  end_date date,
  goal_leads integer check (goal_leads between 0 and 1000000),
  goal_sales integer check (goal_sales between 0 and 1000000),
  budget numeric(12,2) check (budget between 0 and 100000000),
  owner_id uuid references public.boha_employees(id) on delete set null,
  link text check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$')),
  notes text not null default '' check (char_length(notes) <= 2000),
  status text not null default 'planning' check (status in ('planning','running','done')),
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create table if not exists public.boha_campaign_tasks (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.boha_campaigns(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  owner_id uuid references public.boha_employees(id) on delete set null,
  due_date date,
  done boolean not null default false,
  done_at timestamptz,
  sort integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists boha_campaign_tasks_campaign on public.boha_campaign_tasks(campaign_id, sort);
create table if not exists public.boha_funnel_entries (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  ref_date date not null check (ref_date between date '2020-01-01' and date '2100-01-01'),
  leads integer not null default 0 check (leads between 0 and 1000000),
  trials_booked integer not null default 0 check (trials_booked between 0 and 1000000),
  trials_done integer not null default 0 check (trials_done between 0 and 1000000),
  sales integer not null default 0 check (sales between 0 and 1000000),
  spend numeric(12,2) check (spend between 0 and 100000000),
  note text not null default '' check (char_length(note) <= 200),
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit, ref_date)
);
create index if not exists boha_funnel_entries_date on public.boha_funnel_entries(ref_date, unit);
create table if not exists public.boha_campaign_ideas (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  note text not null default '' check (char_length(note) <= 1000),
  month_hint smallint check (month_hint between 1 and 12),
  link text check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$')),
  status text not null default 'open' check (status in ('open','used')),
  campaign_id uuid references public.boha_campaigns(id) on delete set null,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.boha_campaigns_stamp() returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' and to_jsonb(new) ? 'created_by' then new.created_by := coalesce(lower(auth.jwt()->>'email'), new.created_by); end if;
  if tg_op <> 'DELETE' and to_jsonb(new) ? 'updated_by' then new.updated_by := coalesce(lower(auth.jwt()->>'email'), new.updated_by); end if;
  return new;
end $$;
drop trigger if exists boha_campaigns_stamp on public.boha_campaigns;
create trigger boha_campaigns_stamp before insert or update on public.boha_campaigns for each row execute function public.boha_campaigns_stamp();
drop trigger if exists boha_funnel_stamp on public.boha_funnel_entries;
create trigger boha_funnel_stamp before insert or update on public.boha_funnel_entries for each row execute function public.boha_campaigns_stamp();
drop trigger if exists boha_campaign_ideas_stamp on public.boha_campaign_ideas;
create trigger boha_campaign_ideas_stamp before insert or update on public.boha_campaign_ideas for each row execute function public.boha_campaigns_stamp();

do $$ declare t text; begin
  foreach t in array array['boha_campaigns','boha_campaign_tasks','boha_funnel_entries','boha_campaign_ideas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists campanhas_access on public.%I', t);
    execute format('create policy campanhas_access on public.%I for all to authenticated using (public.boha_can(%L)) with check (public.boha_can(%L))', t, 'campanhas', 'campanhas');
  end loop;
end $$;

-- O módulo "campanhas" entra na lista de permissões por perfil.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'campanhas')
  where role in ('gerente','marketing') and not ('campanhas' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Campanhas',
  'Planeje a campanha do mês com metas e checklist, acompanhe o funil de vendas (lead → experimental → matrícula), guarde ideias de campanha e veja o balanço mês a mês.',
  'campanhas',array['admin','gerente','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Campanhas');
