-- Barra lateral de ideias do Calendário editorial.
create table if not exists public.boha_editorial_ideas (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  link text check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$')),
  note text not null default '' check (char_length(note) <= 1000),
  unit text check (unit is null or unit in ('cb','te','ma')),
  recorder_id uuid references public.boha_employees(id) on delete set null,
  sent_by text not null default '' check (char_length(sent_by) <= 80),
  status text not null default 'open' check (status in ('open','done')),
  item_id uuid references public.boha_editorial_items(id) on delete set null,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists boha_editorial_ideas_status on public.boha_editorial_ideas(status, created_at desc);
alter table public.boha_editorial_ideas enable row level security;
revoke all on public.boha_editorial_ideas from anon;
grant select, insert, update, delete on public.boha_editorial_ideas to authenticated;
drop policy if exists editorial_ideas_access on public.boha_editorial_ideas;
create policy editorial_ideas_access on public.boha_editorial_ideas for all to authenticated
  using (public.boha_can('calendario')) with check (public.boha_can('calendario'));
create or replace function public.boha_editorial_ideas_stamp() returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then new.created_by := coalesce(lower(auth.jwt()->>'email'), new.created_by); end if;
  return new;
end $$;
drop trigger if exists boha_editorial_ideas_stamp on public.boha_editorial_ideas;
create trigger boha_editorial_ideas_stamp before insert or update on public.boha_editorial_ideas for each row execute function public.boha_editorial_ideas_stamp();

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Calendário editorial: nova barra de ideias',
  'Guarde ideias com o link do Reels ou post de referência, uma nota, quem pode gravar e quem mandou a referência. Arraste uma ideia para um dia do calendário (ou use "Virar pauta") para agendar.',
  'calendario',array['admin','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Calendário editorial: nova barra de ideias');
