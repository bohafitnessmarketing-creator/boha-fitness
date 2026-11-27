-- Toda tarefa da Rotina da recepção pode ter anotação. Cada anotação avisa no sino o gerente da unidade.
alter table public.boha_routine_notes add column if not exists routine_id uuid references public.boha_routines(id) on delete cascade;
create index if not exists boha_routine_notes_routine on public.boha_routine_notes(routine_id, note_date);

create or replace function public.boha_rnote_task_add(p_routine uuid, p_unit text, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role public.boha_access.role%type := public.boha_role();
        v_today date := (now() at time zone 'America/Sao_Paulo')::date; v_body text := trim(coalesce(p_body,''));
        v_id uuid; v_name text; r record;
begin
  if not (public.boha_can('rotina') and v_role in ('recepcao','admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_unit is null or p_unit not in ('cb','te','ma') or not public.boha_unit_ok(p_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  select * into r from public.boha_routines x where x.id = p_routine and x.active and (x.unit is null or x.unit = p_unit);
  if not found then raise exception 'Tarefa não encontrada.'; end if;
  if (select count(*) from public.boha_routine_notes n where n.routine_id = p_routine and n.note_date = v_today and n.author_email = v_me) >= 10 then
    raise exception 'Limite de anotações desta tarefa hoje atingido.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(v_me,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  insert into public.boha_routine_notes(unit, person_email, note_date, kind, body, author_email, author_name, routine_id)
    values (p_unit, v_me, v_today, 'recepcao', v_body, v_me, left(v_name,80), p_routine) returning id into v_id;
  perform public.boha_notify_unit_managers(p_unit, left('Anotação na Rotina · ' || public.boha_unit_name(p_unit), 120),
    left(coalesce(v_name,'A recepção') || ' em "' || r.title || '": ' || v_body, 560), 'rotina');
  return v_id;
end $$;
revoke all on function public.boha_rnote_task_add(uuid,text,text) from public, anon;
grant execute on function public.boha_rnote_task_add(uuid,text,text) to authenticated;
