-- Módulo "Criação de artes" (Gerente e Administrador): cota diária, histórico que expira em 30 dias e arquivos privados.

-- Uso por dia (a cota não pode ser burlada apagando o histórico). Só a função do servidor escreve aqui.
create table if not exists public.boha_art_usage (
  email text not null check (email = lower(email)),
  day date not null,
  n integer not null default 0 check (n >= 0),
  primary key (email, day)
);
alter table public.boha_art_usage enable row level security;
revoke all on public.boha_art_usage from anon, authenticated;

create table if not exists public.boha_art_history (
  id uuid primary key default gen_random_uuid(),
  created_by text not null check (created_by = lower(created_by)),
  created_by_name text check (created_by_name is null or char_length(created_by_name) <= 80),
  unit text check (unit is null or unit in ('cb','te','ma')),
  format text not null check (format in ('9x16','4x3','16x9')),
  objective text not null default '' check (char_length(objective) <= 120),
  input_text text not null check (char_length(input_text) <= 600),
  direction jsonb not null default '{}'::jsonb,
  final_path text check (final_path is null or char_length(final_path) <= 200),
  status text not null default 'pending' check (status in ('pending','ok')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days')
);
create index if not exists boha_art_history_user on public.boha_art_history(created_by, created_at desc);
create index if not exists boha_art_history_exp on public.boha_art_history(expires_at);
alter table public.boha_art_history enable row level security;
revoke all on public.boha_art_history from anon;
grant select, delete on public.boha_art_history to authenticated;
drop policy if exists art_read on public.boha_art_history;
create policy art_read on public.boha_art_history for select to authenticated
  using (public.boha_can('artes') and expires_at > now() and (created_by = lower(auth.jwt()->>'email') or public.boha_is_admin()));
drop policy if exists art_delete on public.boha_art_history;
create policy art_delete on public.boha_art_history for delete to authenticated
  using (public.boha_can('artes') and (created_by = lower(auth.jwt()->>'email') or public.boha_is_admin()));
drop policy if exists unit_scope on public.boha_art_history;
create policy unit_scope on public.boha_art_history as restrictive for all to authenticated
  using (unit is null or public.boha_unit_ok(unit));

-- Limite diário: 5 para gerente, 30 para administrador (testes).
create or replace function public.boha_art_limit() returns integer
language sql stable security definer set search_path = '' as $$
  select case public.boha_role() when 'admin' then 30 else 5 end
$$;
create or replace function public.boha_art_quota() returns table(used integer, lim integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('artes') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query select coalesce((select u.n from public.boha_art_usage u where u.email = lower(auth.jwt()->>'email') and u.day = (now() at time zone 'America/Sao_Paulo')::date),0), public.boha_art_limit();
end $$;
-- Reserva uma geração (só a função do servidor chama). Devolve o novo total do dia, ou nulo se o limite acabou.
create or replace function public.boha_art_reserve(p_email text, p_limit integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare v integer;
begin
  insert into public.boha_art_usage(email, day, n) values (lower(p_email), (now() at time zone 'America/Sao_Paulo')::date, 1)
  on conflict (email, day) do update set n = public.boha_art_usage.n + 1 where public.boha_art_usage.n < p_limit
  returning n into v;
  return v;
end $$;
create or replace function public.boha_art_refund(p_email text) returns void
language sql security definer set search_path = '' as $$
  update public.boha_art_usage set n = greatest(n - 1, 0) where email = lower(p_email) and day = (now() at time zone 'America/Sao_Paulo')::date
$$;
revoke all on function public.boha_art_reserve(text,integer), public.boha_art_refund(text) from public, anon, authenticated;
grant execute on function public.boha_art_reserve(text,integer), public.boha_art_refund(text) to service_role;
revoke all on function public.boha_art_limit(), public.boha_art_quota() from public, anon;
grant execute on function public.boha_art_limit(), public.boha_art_quota() to authenticated;

-- Conclui a arte: o cliente subiu o PNG final e registra o caminho (só a própria arte, só o caminho esperado).
create or replace function public.boha_art_finish(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_can('artes') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  update public.boha_art_history set final_path = auth.uid()::text || '/' || p_id::text || '.png', status = 'ok'
    where id = p_id and created_by = lower(auth.jwt()->>'email') and expires_at > now();
  if not found then raise exception 'Arte não encontrada.'; end if;
end $$;
revoke all on function public.boha_art_finish(uuid) from public, anon;
grant execute on function public.boha_art_finish(uuid) to authenticated;

-- Arquivos (privados). Cada pessoa só mexe na própria pasta; administrador vê e apaga todas.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boha-artes','boha-artes',false,8388608,array['image/png']::text[])
on conflict (id) do update set public=false, file_size_limit=8388608, allowed_mime_types=array['image/png']::text[];
drop policy if exists artes_read on storage.objects;
create policy artes_read on storage.objects for select to authenticated
  using (bucket_id='boha-artes' and public.boha_can('artes') and ((storage.foldername(name))[1] = auth.uid()::text or public.boha_is_admin()));
drop policy if exists artes_insert on storage.objects;
create policy artes_insert on storage.objects for insert to authenticated
  with check (bucket_id='boha-artes' and public.boha_can('artes') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists artes_delete on storage.objects;
create policy artes_delete on storage.objects for delete to authenticated
  using (bucket_id='boha-artes' and public.boha_can('artes') and ((storage.foldername(name))[1] = auth.uid()::text or public.boha_is_admin()));

-- Módulo na lista de permissões; por padrão só o Gerente.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'artes') where role = 'gerente' and not ('artes' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Criação de artes',
  'Escreva o texto e o objetivo do post, escolha o formato (9x16, 4x3 ou 16x9) e a Boha gera a arte com o logo e a identidade visual. Até 5 artes por dia; o histórico fica guardado por 30 dias.',
  'artes',array['admin','gerente'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Criação de artes');
