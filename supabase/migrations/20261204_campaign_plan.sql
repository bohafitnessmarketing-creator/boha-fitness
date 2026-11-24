-- Planejamento anual de campanhas: meta anual de contratos e verba anual (a distribuição mensal vem do termômetro sazonal).
create table if not exists public.boha_campaign_plan (
  year integer primary key check (year between 2020 and 2100),
  annual_goal integer check (annual_goal is null or annual_goal between 0 and 10000000),
  annual_budget numeric(14,2) check (annual_budget is null or annual_budget between 0 and 1000000000),
  updated_by text,
  updated_at timestamptz not null default now()
);
alter table public.boha_campaign_plan enable row level security;
revoke all on public.boha_campaign_plan from anon;
grant select, insert, update, delete on public.boha_campaign_plan to authenticated;
drop policy if exists plan_read on public.boha_campaign_plan;
create policy plan_read on public.boha_campaign_plan for select to authenticated using (public.boha_can('campanhas'));
drop policy if exists plan_write on public.boha_campaign_plan;
create policy plan_write on public.boha_campaign_plan for all to authenticated
  using (public.boha_can('campanhas') and public.boha_role() = any (array['admin','marketing','dono']))
  with check (public.boha_can('campanhas') and public.boha_role() = any (array['admin','marketing','dono']));
create or replace function public.boha_campaign_plan_stamp() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := coalesce(lower(auth.jwt()->>'email'), new.updated_by); return new; end $$;
drop trigger if exists boha_campaign_plan_stamp on public.boha_campaign_plan;
create trigger boha_campaign_plan_stamp before insert or update on public.boha_campaign_plan for each row execute function public.boha_campaign_plan_stamp();
