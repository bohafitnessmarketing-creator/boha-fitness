-- Rotina da recepção: anotações, remoção de recepcionista pelo gerente (da própria unidade) e exclusão no Banco de funcionários.

-- ---------------------------------------------------------------- anotações
-- kind 'recepcao': a recepcionista anota o próprio dia (ela e o gerente leem).
-- kind 'gestor': o gerente anota sobre uma recepcionista (privada: só gerente da unidade e administrador leem).
create table if not exists public.boha_routine_notes (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  person_email text not null,
  note_date date not null check (note_date between date '2020-01-01' and date '2100-01-01'),
  kind text not null check (kind in ('gestor','recepcao')),
  body text not null check (char_length(body) between 1 and 1000),
  author_email text not null,
  author_name text check (author_name is null or char_length(author_name) <= 80),
  created_at timestamptz not null default now()
);
create index if not exists boha_routine_notes_unit_date on public.boha_routine_notes(unit, note_date);
create index if not exists boha_routine_notes_person on public.boha_routine_notes(person_email, note_date);
alter table public.boha_routine_notes enable row level security;
revoke all on public.boha_routine_notes from anon, authenticated;
grant select on public.boha_routine_notes to authenticated;
drop policy if exists rnotes_read on public.boha_routine_notes;
create policy rnotes_read on public.boha_routine_notes for select to authenticated using (
  public.boha_can('rotina') and (
    (public.boha_role() in ('gerente','admin') and public.boha_unit_ok(unit))
    or (public.boha_role() = 'recepcao' and kind = 'recepcao' and person_email = lower(auth.jwt()->>'email'))));

create or replace function public.boha_rnote_add(p_person text, p_date date, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role text := public.boha_role(); v_unit text; v_kind text;
        v_body text := trim(coalesce(p_body,'')); v_person text := lower(trim(coalesce(p_person,'')));
        v_today date := (now() at time zone 'America/Sao_Paulo')::date; v_id uuid; v_name text;
begin
  if not public.boha_can('rotina') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  if p_date is null or p_date > v_today or p_date < v_today - 120 then raise exception 'Data inválida.'; end if;
  if v_role = 'recepcao' then
    select a.unit into v_unit from public.boha_access a where a.email = v_me;
    if v_unit is null then raise exception 'Sua unidade ainda não foi definida.'; end if;
    if p_date <> v_today then raise exception 'A recepção anota apenas o dia de hoje.'; end if;
    v_person := v_me; v_kind := 'recepcao';
  elsif v_role in ('gerente','admin') then
    select a.unit into v_unit from public.boha_access a where a.email = v_person and a.role = 'recepcao';
    if v_unit is null then raise exception 'Recepcionista não encontrada.'; end if;
    if not public.boha_unit_ok(v_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
    v_kind := 'gestor';
  else raise exception 'Acesso negado.' using errcode='42501'; end if;
  if (select count(*) from public.boha_routine_notes n where n.person_email = v_person and n.note_date = p_date and n.author_email = v_me) >= 20 then
    raise exception 'Limite de anotações deste dia atingido.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  insert into public.boha_routine_notes(unit, person_email, note_date, kind, body, author_email, author_name)
    values (v_unit, v_person, p_date, v_kind, v_body, v_me, left(v_name, 80)) returning id into v_id;
  return v_id;
end $$;

create or replace function public.boha_rnote_delete(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare n public.boha_routine_notes%rowtype;
begin
  if not public.boha_can('rotina') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into n from public.boha_routine_notes where id = p_id;
  if not found then return; end if;
  if not (n.author_email = lower(auth.jwt()->>'email') or (public.boha_role() = 'admin')) then raise exception 'Você só pode excluir as suas anotações.' using errcode='42501'; end if;
  delete from public.boha_routine_notes where id = p_id;
end $$;

-- ---------------------------------------------------------------- remover recepcionista
-- Tira o acesso da recepcionista (ela deixa de entrar no sistema e some do painel). O histórico de marcações fica guardado.
create or replace function public.boha_reception_remove(p_email text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email,''))); a public.boha_access%rowtype; v_me text := lower(auth.jwt()->>'email'); v_by text;
begin
  if not (public.boha_can('rotina') and public.boha_role() in ('gerente','admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into a from public.boha_access x where x.email = v_email;
  if not found or a.role <> 'recepcao' then raise exception 'Recepcionista não encontrada.'; end if;
  if a.unit is null or not public.boha_unit_ok(a.unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  delete from public.boha_access where email = v_email;
  select coalesce(nullif(trim(x.name),''), initcap(split_part(x.email,'@',1))) into v_by from public.boha_access x where x.email = v_me;
  insert into public.boha_notices(title, body, module, audience, created_by)
  values (left('Acesso removido: ' || coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))), 120),
          left('Recepção · ' || case a.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' else 'Macedônia' end || ' · removido por ' || coalesce(v_by, v_me) || '.', 300),
          'rotina', array['admin']::text[], 'Sistema BOHA');
end $$;

revoke all on function public.boha_rnote_add(text,date,text), public.boha_rnote_delete(uuid), public.boha_reception_remove(text) from public, anon;
grant execute on function public.boha_rnote_add(text,date,text), public.boha_rnote_delete(uuid), public.boha_reception_remove(text) to authenticated;

-- ---------------------------------------------------------------- Banco de funcionários: gerente exclui (só da própria unidade)
-- A trava por unidade (política restritiva unit_scope) já vale para exclusão. Marketing continua sem excluir.
drop policy if exists employees_gerente_delete on public.boha_employees;
create policy employees_gerente_delete on public.boha_employees for delete to authenticated
  using (public.boha_role() = 'gerente' and public.boha_can('funcionarios'));

-- O gerente passa a ter o Banco de funcionários (só da própria unidade: ver, cadastrar, editar e excluir).
update public.boha_role_modules set modules = array_append(modules,'funcionarios')
  where role = 'gerente' and not ('funcionarios' = any(modules));
