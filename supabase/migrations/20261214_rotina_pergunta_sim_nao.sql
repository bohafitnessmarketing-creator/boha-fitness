-- Rotina da recepção: tarefa com pergunta Sim/Não.
--   Não  -> a tarefa já fica concluída.
--   Sim  -> a recepção precisa registrar o ID do aluno e uma anotação (pode registrar mais de um aluno no dia).
-- Vale para as tarefas que o gerente marcar com uma pergunta (ao salvar a tarefa). Já vem ligado em:
--   "Registrar solicitações de cancelamento e transferência" e "Conferir pagamentos e situações de inadimplência".

alter table public.boha_routines add column if not exists ask text check (ask is null or char_length(ask) between 3 and 160);
alter table public.boha_routine_checks add column if not exists answer text check (answer is null or answer in ('sim','nao'));

create table if not exists public.boha_routine_records (
  id uuid primary key default gen_random_uuid(),
  check_id uuid not null references public.boha_routine_checks(id) on delete cascade,
  routine_id uuid not null references public.boha_routines(id) on delete cascade,
  unit text not null check (unit in ('cb','te','ma')),
  check_date date not null,
  student_id text not null check (char_length(student_id) between 1 and 40),
  note text not null check (char_length(note) between 1 and 1000),
  done_by text not null,
  done_by_name text check (done_by_name is null or char_length(done_by_name) <= 80),
  created_at timestamptz not null default now()
);
create index if not exists boha_routine_records_day on public.boha_routine_records(check_date, unit);
create index if not exists boha_routine_records_check on public.boha_routine_records(check_id);

alter table public.boha_routine_records enable row level security;
revoke all on public.boha_routine_records from anon, authenticated;
grant select on public.boha_routine_records to authenticated;
drop policy if exists rec_read on public.boha_routine_records;
create policy rec_read on public.boha_routine_records for select to authenticated
  using (public.boha_can('rotina') and (public.boha_role() <> 'recepcao' or done_by = lower(auth.jwt()->>'email')));
drop policy if exists unit_scope on public.boha_routine_records;
create policy unit_scope on public.boha_routine_records as restrictive for all to authenticated
  using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit));

-- Responder a pergunta de hoje. 'nao' conclui; 'sim' exige ID do aluno e anotação e pode ser repetido (um registro por aluno).
create or replace function public.boha_routine_answer(p_routine uuid, p_unit text, p_answer text, p_student text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role text := public.boha_role();
        v_today date := (now() at time zone 'America/Sao_Paulo')::date;
        r record; c record; v_id uuid; v_name text;
        v_stu text := trim(coalesce(p_student,'')); v_note text := trim(coalesce(p_note,''));
begin
  if not (public.boha_can('rotina') and v_role in ('recepcao','admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_unit is null or p_unit not in ('cb','te','ma') or not public.boha_unit_ok(p_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_answer not in ('sim','nao') then raise exception 'Responda Sim ou Não.'; end if;
  select * into r from public.boha_routines x where x.id = p_routine and x.active and x.ask is not null and (x.unit is null or x.unit = p_unit);
  if not found then raise exception 'Tarefa não encontrada.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(v_me,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  select * into c from public.boha_routine_checks k where k.routine_id = p_routine and k.unit = p_unit and k.check_date = v_today;
  if found and c.done_by <> v_me and v_role <> 'admin' then raise exception 'Esta tarefa já foi respondida por outra pessoa hoje.'; end if;
  if p_answer = 'nao' then
    if found then
      if exists (select 1 from public.boha_routine_records z where z.check_id = c.id) then raise exception 'Já existem registros de Sim. Apague-os antes de responder Não.'; end if;
      update public.boha_routine_checks set answer = 'nao' where id = c.id;
      return c.id;
    end if;
    insert into public.boha_routine_checks(routine_id, unit, check_date, done_by, done_by_name, answer)
      values (p_routine, p_unit, v_today, v_me, left(v_name,80), 'nao') returning id into v_id;
    return v_id;
  end if;
  if char_length(v_stu) < 1 or char_length(v_stu) > 40 then raise exception 'Informe o ID do aluno.'; end if;
  if char_length(v_note) < 1 or char_length(v_note) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  if (select count(*) from public.boha_routine_records z where z.routine_id = p_routine and z.unit = p_unit and z.check_date = v_today) >= 30 then
    raise exception 'Limite de registros do dia atingido.'; end if;
  if found then
    v_id := c.id; update public.boha_routine_checks set answer = 'sim' where id = c.id;
  else
    insert into public.boha_routine_checks(routine_id, unit, check_date, done_by, done_by_name, answer)
      values (p_routine, p_unit, v_today, v_me, left(v_name,80), 'sim') returning id into v_id;
  end if;
  insert into public.boha_routine_records(check_id, routine_id, unit, check_date, student_id, note, done_by, done_by_name)
    values (v_id, p_routine, p_unit, v_today, v_stu, v_note, v_me, left(v_name,80));
  return v_id;
end $$;
revoke all on function public.boha_routine_answer(uuid,text,text,text,text) from public, anon;
grant execute on function public.boha_routine_answer(uuid,text,text,text,text) to authenticated;

-- Apagar um registro (quem fez ou administrador). Sem nenhum registro restante, a tarefa volta a ficar pendente.
create or replace function public.boha_routine_record_delete(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); rec record;
begin
  if not public.boha_can('rotina') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into rec from public.boha_routine_records where id = p_id;
  if not found then return; end if;
  if not (public.boha_unit_ok(rec.unit) and (rec.done_by = v_me or public.boha_role() = 'admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if rec.check_date <> (now() at time zone 'America/Sao_Paulo')::date and public.boha_role() <> 'admin' then raise exception 'Só dá para apagar registros de hoje.'; end if;
  delete from public.boha_routine_records where id = p_id;
  if not exists (select 1 from public.boha_routine_records where check_id = rec.check_id) then
    delete from public.boha_routine_checks where id = rec.check_id;
  end if;
end $$;
revoke all on function public.boha_routine_record_delete(uuid) from public, anon;
grant execute on function public.boha_routine_record_delete(uuid) to authenticated;

-- Tarefas que já nascem com a pergunta (modelo da recepção e tarefas existentes)
create or replace function public.boha_routines_default_ask() returns trigger language plpgsql as $$
begin
  if new.ask is null and new.role_name = 'Recepção' then
    if new.title = 'Registrar solicitações de cancelamento e transferência' then new.ask := 'Houve solicitação de cancelamento ou transferência?';
    elsif new.title = 'Conferir pagamentos e situações de inadimplência' then new.ask := 'Há aluno com pagamento pendente ou inadimplência?'; end if;
  end if;
  return new;
end $$;
drop trigger if exists boha_routines_default_ask on public.boha_routines;
create trigger boha_routines_default_ask before insert on public.boha_routines for each row execute function public.boha_routines_default_ask();

update public.boha_routines set ask = 'Houve solicitação de cancelamento ou transferência?'
  where role_name = 'Recepção' and ask is null and title = 'Registrar solicitações de cancelamento e transferência';
update public.boha_routines set ask = 'Há aluno com pagamento pendente ou inadimplência?'
  where role_name = 'Recepção' and ask is null and title = 'Conferir pagamentos e situações de inadimplência';

-- Tarefa com pergunta só pode ser concluída respondendo (pela função acima), nunca por marcação direta.
drop policy if exists checks_no_direct_ask on public.boha_routine_checks;
create policy checks_no_direct_ask on public.boha_routine_checks as restrictive for insert to authenticated
  with check (not exists (select 1 from public.boha_routines r where r.id = routine_id and r.ask is not null));
