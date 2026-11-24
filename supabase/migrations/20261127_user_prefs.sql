-- Preferências pessoais do sistema interno (ordem dos módulos no início). Cada pessoa só enxerga e altera a própria linha.
create table if not exists public.boha_user_prefs (
  email text primary key check (email = lower(email)),
  module_order text[] not null default '{}' check (cardinality(module_order) <= 60),
  updated_at timestamptz not null default now()
);
alter table public.boha_user_prefs enable row level security;
revoke all on public.boha_user_prefs from anon;
grant select, insert, update on public.boha_user_prefs to authenticated;
drop policy if exists prefs_own on public.boha_user_prefs;
create policy prefs_own on public.boha_user_prefs for all to authenticated
  using (email = lower(auth.jwt()->>'email')) with check (email = lower(auth.jwt()->>'email'));
