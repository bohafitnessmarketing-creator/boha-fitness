-- Avisos no sino do gerente da unidade (inclui gerentes com mais de uma unidade):
--   * quando a recepção escreve uma anotação no dia;
--   * quando a recepção responde Sim numa tarefa da Rotina (ID do aluno + anotação).
-- Também avisa os gerentes que têm a unidade como extra quando chega candidato no Banco de talentos.

create or replace function public.boha_unit_name(u text) returns text language sql immutable set search_path = '' as $$
  select case u when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' when 'ma' then 'Macedônia' else '' end $$;

create or replace function public.boha_notify_unit_managers(p_unit text, p_title text, p_body text, p_module text) returns void
language sql security definer set search_path = '' as $$
  insert into public.boha_notices(title, body, module, audience, created_by, to_email)
  select p_title, p_body, p_module, array['gerente']::text[], 'Sistema BOHA', a.email
    from public.boha_access a
   where a.role = 'gerente' and (a.unit = p_unit or p_unit = any(a.extra_units))
$$;
revoke all on function public.boha_notify_unit_managers(text,text,text,text) from public, anon, authenticated;

create or replace function public.boha_routine_answer(p_routine uuid, p_unit text, p_answer text, p_student text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role text := public.boha_role();
        v_today date := (now() at time zone 'America/Sao_Paulo')::date;
        r record; c record; v_id uuid; v_name text; v_unitname text;
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
  perform public.boha_notify_unit_managers(p_unit,
    left('Registro na Rotina · ' || public.boha_unit_name(p_unit), 120),
    left(coalesce(v_name,'A recepção') || ' registrou em "' || r.title || '" · aluno ID ' || v_stu || ': ' || v_note, 560), 'rotina');
  return v_id;
end $$;

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
  if v_kind = 'recepcao' then
    perform public.boha_notify_unit_managers(v_unit, left('Anotação da recepção · ' || public.boha_unit_name(v_unit), 120),
      left(coalesce(v_name,'A recepção') || ': ' || v_body, 560), 'rotina');
  end if;
  return v_id;
end $$;


create or replace function public.boha_talent_notify_extra() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.boha_notices(title, body, module, audience, created_by, to_email)
  select left('Novo candidato: ' || split_part(new.name, ' ', 1), 120),
         left('Jovem Aprendiz · Recepção · ' || public.boha_unit_name(new.unit) || '. Veja as respostas no Banco de talentos.', 300),
         'talentos', array['gerente']::text[], 'Sistema BOHA', a.email
    from public.boha_access a where a.role = 'gerente' and a.unit is distinct from new.unit and new.unit = any(a.extra_units);
  return new;
end $$;
drop trigger if exists boha_talent_notify_extra on public.boha_talent_apps;
create trigger boha_talent_notify_extra after insert on public.boha_talent_apps for each row execute function public.boha_talent_notify_extra();
