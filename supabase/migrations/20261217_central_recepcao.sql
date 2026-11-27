-- Central Recepção: recado entre recepcionistas (e gerente) da MESMA unidade.
-- Cada registro leva o ID do aluno, o plano (os 3 planos do site) e a tratativa. Pode ser respondido e marcado como resolvido.
-- Acesso: recepção, gerente (e administrador), cada um só vê a própria unidade.

create table if not exists public.boha_central_posts (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  student_id text not null check (char_length(student_id) between 1 and 40),
  plan text not null check (plan in ('boha_fit','vip_anual','basico')),
  action text not null check (char_length(action) between 1 and 1500),
  status text not null default 'aberto' check (status in ('aberto','resolvido')),
  created_by text not null,
  created_by_name text check (created_by_name is null or char_length(created_by_name) <= 80),
  created_at timestamptz not null default now(),
  resolved_by_name text check (resolved_by_name is null or char_length(resolved_by_name) <= 80),
  resolved_at timestamptz
);
create index if not exists boha_central_posts_unit on public.boha_central_posts(unit, created_at desc);
create index if not exists boha_central_posts_student on public.boha_central_posts(unit, student_id);
create table if not exists public.boha_central_replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.boha_central_posts(id) on delete cascade,
  unit text not null check (unit in ('cb','te','ma')),
  body text not null check (char_length(body) between 1 and 800),
  created_by text not null,
  created_by_name text check (created_by_name is null or char_length(created_by_name) <= 80),
  created_at timestamptz not null default now()
);
create index if not exists boha_central_replies_post on public.boha_central_replies(post_id, created_at);

create or replace function public.boha_central_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('central') and public.boha_role() in ('recepcao','gerente','admin')
$$;
revoke all on function public.boha_central_ok() from public, anon;
grant execute on function public.boha_central_ok() to authenticated;

alter table public.boha_central_posts enable row level security;
alter table public.boha_central_replies enable row level security;
revoke all on public.boha_central_posts, public.boha_central_replies from anon, authenticated;
grant select on public.boha_central_posts, public.boha_central_replies to authenticated;
drop policy if exists central_read on public.boha_central_posts;
create policy central_read on public.boha_central_posts for select to authenticated using (public.boha_central_ok());
drop policy if exists central_scope on public.boha_central_posts;
create policy central_scope on public.boha_central_posts as restrictive for all to authenticated using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit));
drop policy if exists central_r_read on public.boha_central_replies;
create policy central_r_read on public.boha_central_replies for select to authenticated using (public.boha_central_ok());
drop policy if exists central_r_scope on public.boha_central_replies;
create policy central_r_scope on public.boha_central_replies as restrictive for all to authenticated using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit));

create or replace function public.boha_central_name() returns text language sql stable security definer set search_path = '' as $$
  select left(coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))), 80) from public.boha_access a where a.email = lower(auth.jwt()->>'email')
$$;
revoke all on function public.boha_central_name() from public, anon;
grant execute on function public.boha_central_name() to authenticated;

create or replace function public.boha_central_post(p_unit text, p_student text, p_plan text, p_action text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_id uuid; v_stu text := trim(coalesce(p_student,'')); v_act text := trim(coalesce(p_action,''));
begin
  if not public.boha_central_ok() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_unit is null or p_unit not in ('cb','te','ma') or not public.boha_unit_ok(p_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if char_length(v_stu) < 1 or char_length(v_stu) > 40 then raise exception 'Informe o ID do aluno.'; end if;
  if p_plan is null or p_plan not in ('boha_fit','vip_anual','basico') then raise exception 'Escolha o plano do aluno.'; end if;
  if char_length(v_act) < 1 or char_length(v_act) > 1500 then raise exception 'Escreva a tratativa (até 1500 caracteres).'; end if;
  if (select count(*) from public.boha_central_posts x where x.created_by = v_me and x.created_at > now() - interval '1 day') >= 100 then raise exception 'Limite diário de registros atingido.'; end if;
  insert into public.boha_central_posts(unit, student_id, plan, action, created_by, created_by_name)
    values (p_unit, v_stu, p_plan, v_act, v_me, public.boha_central_name()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.boha_central_reply(p_post uuid, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_id uuid; p record; v_body text := trim(coalesce(p_body,''));
begin
  if not public.boha_central_ok() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into p from public.boha_central_posts where id = p_post;
  if not found or not public.boha_unit_ok(p.unit) then raise exception 'Registro não encontrado.'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 800 then raise exception 'Escreva a resposta (até 800 caracteres).'; end if;
  if (select count(*) from public.boha_central_replies x where x.created_by = v_me and x.created_at > now() - interval '1 day') >= 200 then raise exception 'Limite diário atingido.'; end if;
  insert into public.boha_central_replies(post_id, unit, body, created_by, created_by_name) values (p_post, p.unit, v_body, v_me, public.boha_central_name()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.boha_central_status(p_post uuid, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  if not public.boha_central_ok() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_status not in ('aberto','resolvido') then raise exception 'Situação inválida.'; end if;
  select * into p from public.boha_central_posts where id = p_post;
  if not found or not public.boha_unit_ok(p.unit) then raise exception 'Registro não encontrado.'; end if;
  update public.boha_central_posts set status = p_status,
    resolved_by_name = case when p_status = 'resolvido' then public.boha_central_name() end,
    resolved_at = case when p_status = 'resolvido' then now() end where id = p_post;
end $$;

-- Apagar: quem escreveu, o gerente da unidade ou o administrador.
create or replace function public.boha_central_delete(p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  if not public.boha_central_ok() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into p from public.boha_central_posts where id = p_post;
  if not found then return; end if;
  if not public.boha_unit_ok(p.unit) or not (p.created_by = lower(auth.jwt()->>'email') or public.boha_role() in ('gerente','admin')) then
    raise exception 'Você só pode apagar os seus registros.' using errcode='42501'; end if;
  delete from public.boha_central_posts where id = p_post;
end $$;
create or replace function public.boha_central_reply_delete(p_reply uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if not public.boha_central_ok() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into r from public.boha_central_replies where id = p_reply;
  if not found then return; end if;
  if not public.boha_unit_ok(r.unit) or not (r.created_by = lower(auth.jwt()->>'email') or public.boha_role() in ('gerente','admin')) then
    raise exception 'Você só pode apagar as suas respostas.' using errcode='42501'; end if;
  delete from public.boha_central_replies where id = p_reply;
end $$;
revoke all on function public.boha_central_post(text,text,text,text), public.boha_central_reply(uuid,text), public.boha_central_status(uuid,text), public.boha_central_delete(uuid), public.boha_central_reply_delete(uuid) from public, anon;
grant execute on function public.boha_central_post(text,text,text,text), public.boha_central_reply(uuid,text), public.boha_central_status(uuid,text), public.boha_central_delete(uuid), public.boha_central_reply_delete(uuid) to authenticated;

-- Módulo nas permissões: só recepção e gerente (o administrador tem tudo)
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos','mapas','central']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos','mapas','central')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'central') where role in ('gerente','recepcao') and not ('central' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Central Recepção',
  'Recado entre a recepção da unidade: registre o ID do aluno, o plano e a tratativa para o próximo turno continuar de onde você parou.',
  'central',array['gerente','recepcao']::text[],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Central Recepção');
