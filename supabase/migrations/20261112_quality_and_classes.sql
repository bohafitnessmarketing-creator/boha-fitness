create table if not exists public.boha_professor_ratings (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  professor text not null check (length(professor) between 1 and 120),
  pessimo integer not null default 0 check (pessimo >= 0),
  ruim integer not null default 0 check (ruim >= 0),
  regular integer not null default 0 check (regular >= 0),
  bom integer not null default 0 check (bom >= 0),
  otimo integer not null default 0 check (otimo >= 0),
  created_at timestamptz not null default now(),
  unique (unit, professor)
);
alter table public.boha_professor_ratings enable row level security;
revoke all on public.boha_professor_ratings from anon;
grant select, insert, update, delete on public.boha_professor_ratings to authenticated;
drop policy if exists professor_ratings_admin_read on public.boha_professor_ratings;
create policy professor_ratings_admin_read on public.boha_professor_ratings for select to authenticated using (public.boha_role() = 'admin');
drop policy if exists professor_ratings_admin_insert on public.boha_professor_ratings;
create policy professor_ratings_admin_insert on public.boha_professor_ratings for insert to authenticated with check (public.boha_role() = 'admin');
drop policy if exists professor_ratings_admin_update on public.boha_professor_ratings;
create policy professor_ratings_admin_update on public.boha_professor_ratings for update to authenticated using (public.boha_role() = 'admin') with check (public.boha_role() = 'admin');
drop policy if exists professor_ratings_admin_delete on public.boha_professor_ratings;
create policy professor_ratings_admin_delete on public.boha_professor_ratings for delete to authenticated using (public.boha_role() = 'admin');

create table if not exists public.boha_class_postings (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  class_name text not null check (length(class_name) between 1 and 80),
  post_dates date[] not null default '{}',
  updated_at timestamptz not null default now(),
  unique (unit, class_name)
);
alter table public.boha_class_postings enable row level security;
revoke all on public.boha_class_postings from anon;
grant select, insert, update, delete on public.boha_class_postings to authenticated;
drop policy if exists class_postings_read on public.boha_class_postings;
create policy class_postings_read on public.boha_class_postings for select to authenticated using (public.boha_can('marketing'));
drop policy if exists class_postings_insert on public.boha_class_postings;
create policy class_postings_insert on public.boha_class_postings for insert to authenticated with check (public.boha_role() in ('admin','marketing'));
drop policy if exists class_postings_update on public.boha_class_postings;
create policy class_postings_update on public.boha_class_postings for update to authenticated using (public.boha_role() in ('admin','marketing')) with check (public.boha_role() in ('admin','marketing'));
drop policy if exists class_postings_delete on public.boha_class_postings;
create policy class_postings_delete on public.boha_class_postings for delete to authenticated using (public.boha_role() = 'admin');

create table if not exists public.boha_class_schedule (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  weekday integer not null check (weekday between 1 and 6),
  start_time time not null,
  class_name text not null check (length(class_name) between 1 and 80),
  created_at timestamptz not null default now(),
  unique (unit, weekday, start_time, class_name)
);
alter table public.boha_class_schedule enable row level security;
revoke all on public.boha_class_schedule from anon;
grant select, insert, update, delete on public.boha_class_schedule to authenticated;
drop policy if exists class_schedule_read on public.boha_class_schedule;
create policy class_schedule_read on public.boha_class_schedule for select to authenticated using (public.boha_can('marketing'));
drop policy if exists class_schedule_insert on public.boha_class_schedule;
create policy class_schedule_insert on public.boha_class_schedule for insert to authenticated with check (public.boha_role() in ('admin','marketing'));
drop policy if exists class_schedule_update on public.boha_class_schedule;
create policy class_schedule_update on public.boha_class_schedule for update to authenticated using (public.boha_role() in ('admin','marketing')) with check (public.boha_role() in ('admin','marketing'));
drop policy if exists class_schedule_delete on public.boha_class_schedule;
create policy class_schedule_delete on public.boha_class_schedule for delete to authenticated using (public.boha_role() = 'admin');
