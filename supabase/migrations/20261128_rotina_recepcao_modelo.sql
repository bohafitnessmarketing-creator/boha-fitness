-- Rotina da recepção: checklist completo em 6 blocos, uma marcação por recepcionista, painel do gerente por pessoa.
alter table public.boha_routines add column if not exists block text;
alter table public.boha_routines add column if not exists hint text;
alter table public.boha_routines drop constraint if exists boha_routines_block_check;
alter table public.boha_routines add constraint boha_routines_block_check check (block is null or block in ('abertura','atendimento','vendas','renovacoes','administrativo','fechamento'));
alter table public.boha_routines drop constraint if exists boha_routines_hint_check;
alter table public.boha_routines add constraint boha_routines_hint_check check (hint is null or char_length(hint) <= 300);
alter table public.boha_routines alter column moment drop not null;

-- Marcação por pessoa (antes era uma por unidade)
do $$ declare c text; begin
  for c in select conname from pg_constraint where conrelid='public.boha_routine_checks'::regclass and contype='u' loop
    execute format('alter table public.boha_routine_checks drop constraint %I', c);
  end loop;
end $$;
alter table public.boha_routine_checks alter column done_by set not null;
alter table public.boha_routine_checks add constraint boha_routine_checks_person_day unique (routine_id, check_date, done_by);

drop policy if exists checks_read on public.boha_routine_checks;
create policy checks_read on public.boha_routine_checks for select to authenticated
  using (public.boha_can('rotina') and (public.boha_role() <> 'recepcao' or done_by = lower(auth.jwt()->>'email')));
drop policy if exists checks_delete on public.boha_routine_checks;
create policy checks_delete on public.boha_routine_checks for delete to authenticated
  using (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']) and done_by = lower(auth.jwt()->>'email'));

-- Passagem de turno (uma por pessoa por dia)
create table if not exists public.boha_handoffs (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  handoff_date date not null check (handoff_date between date '2020-01-01' and date '2100-01-01'),
  author_email text not null,
  author_name text check (author_name is null or char_length(author_name) <= 80),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object' and pg_column_size(data) < 9000),
  updated_at timestamptz not null default now(),
  unique (author_email, handoff_date)
);
create index if not exists boha_handoffs_unit_date on public.boha_handoffs(unit, handoff_date);
create or replace function public.boha_handoffs_stamp() returns trigger language plpgsql as $$
begin new.author_email := coalesce(lower(auth.jwt()->>'email'), new.author_email); new.updated_at := now(); return new; end $$;
drop trigger if exists boha_handoffs_stamp on public.boha_handoffs;
create trigger boha_handoffs_stamp before insert or update on public.boha_handoffs for each row execute function public.boha_handoffs_stamp();
alter table public.boha_handoffs enable row level security;
revoke all on public.boha_handoffs from anon;
grant select, insert, update on public.boha_handoffs to authenticated;
drop policy if exists handoffs_read on public.boha_handoffs;
create policy handoffs_read on public.boha_handoffs for select to authenticated using (public.boha_can('rotina'));
drop policy if exists handoffs_insert on public.boha_handoffs;
create policy handoffs_insert on public.boha_handoffs for insert to authenticated
  with check (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']));
drop policy if exists handoffs_update on public.boha_handoffs;
create policy handoffs_update on public.boha_handoffs for update to authenticated
  using (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']) and author_email = lower(auth.jwt()->>'email'))
  with check (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']) and author_email = lower(auth.jwt()->>'email'));
drop policy if exists unit_scope on public.boha_handoffs;
create policy unit_scope on public.boha_handoffs as restrictive for all to authenticated
  using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit));

-- Quem são as recepcionistas com acesso na unidade (para o painel do gerente)
create or replace function public.boha_reception_team() returns table(email text, name text, unit text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('rotina') or public.boha_role() = 'recepcao' then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query select a.email::text,
    coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1)))::text, a.unit::text
    from public.boha_access a where a.role = 'recepcao' and a.unit is not null and public.boha_unit_ok(a.unit)
    order by a.unit, 2;
end $$;
revoke all on function public.boha_reception_team() from public, anon;
grant execute on function public.boha_reception_team() to authenticated;

-- Modelo completo da rotina da recepção (uma única fonte da verdade). Só cria se a unidade ainda não tiver o modelo.
create or replace function public.boha_reception_template_apply(p_unit text) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer := 0;
begin
  if p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  if not (public.boha_can('rotina') and public.boha_role() = any (array['admin','gerente','dono','marketing']) and public.boha_unit_ok(p_unit)) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  if exists (select 1 from public.boha_routines where unit = p_unit and role_name = 'Recepção' and block is not null) then return 0; end if;
  insert into public.boha_routines(unit, role_name, block, title, hint, sort)
  select p_unit, 'Recepção', t.block, t.title, t.hint, t.sort from (values
    ('abertura','Conferir a recepção','Balcão organizado e ambiente adequado',1),
    ('abertura','Conferir equipamentos','Computador, telefone e sistema funcionando',2),
    ('abertura','Acessar o Evo','Sistema aberto e disponível',3),
    ('abertura','Conferir mensagens','WhatsApp e demais canais verificados',4),
    ('abertura','Conferir pendências','Identificar o que ficou do turno anterior',5),
    ('abertura','Conferir agenda','Verificar avaliações, visitas e compromissos',6),
    ('atendimento','Recepcionar os alunos com educação e cordialidade',null,7),
    ('atendimento','Cumprimentar e identificar visitantes',null,8),
    ('atendimento','Orientar sobre planos, serviços e funcionamento da academia',null,9),
    ('atendimento','Responder mensagens recebidas',null,10),
    ('atendimento','Atender ligações telefônicas',null,11),
    ('atendimento','Registrar reclamações, sugestões e solicitações',null,12),
    ('atendimento','Acompanhar demandas que dependam de outros colaboradores',null,13),
    ('atendimento','Retornar aos clientes que aguardam respostas',null,14),
    ('vendas','Contatar novos interessados','Realizar contatos com pessoas que demonstraram interesse',15),
    ('vendas','Retomar contatos pendentes','Procurar interessados que ainda não fecharam plano',16),
    ('vendas','Acompanhar avaliações','Conferir interessados que realizaram ou agendaram avaliação',17),
    ('vendas','Apresentar planos','Informar opções, valores e diferenciais',18),
    ('vendas','Registrar vendas','Atualizar o resultado no Evo',19),
    ('vendas','Solicitar indicações','Pedir indicações aos alunos e novos clientes',20),
    ('renovacoes','Conferir alunos com planos próximos do vencimento',null,21),
    ('renovacoes','Realizar contatos de renovação',null,22),
    ('renovacoes','Apresentar as condições de renovação',null,23),
    ('renovacoes','Acompanhar alunos que não responderam',null,24),
    ('renovacoes','Realizar contatos com alunos inativos',null,25),
    ('renovacoes','Registrar os contatos no relacionamento',null,26),
    ('renovacoes','Atualizar o resultado de cada atendimento',null,27),
    ('administrativo','Conferir pagamentos e pendências financeiras',null,28),
    ('administrativo','Verificar alunos inadimplentes',null,29),
    ('administrativo','Realizar cobranças conforme orientação',null,30),
    ('administrativo','Registrar solicitações de cancelamento',null,31),
    ('administrativo','Registrar solicitações de transferência',null,32),
    ('administrativo','Conferir cadastros de novos alunos',null,33),
    ('administrativo','Atualizar informações no sistema',null,34),
    ('administrativo','Registrar ocorrências e situações que precisam de acompanhamento',null,35),
    ('administrativo','Encaminhar demandas administrativas à gestão',null,36),
    ('fechamento','Conferir atendimentos pendentes',null,37),
    ('fechamento','Verificar mensagens sem resposta',null,38),
    ('fechamento','Conferir contatos comerciais que precisam de retorno',null,39),
    ('fechamento','Atualizar tarefas não concluídas',null,40),
    ('fechamento','Registrar ocorrências do expediente',null,41),
    ('fechamento','Organizar a recepção',null,42),
    ('fechamento','Informar à próxima colaboradora as pendências importantes',null,43)
  ) as t(block,title,hint,sort);
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.boha_reception_template_apply(text) from public, anon;
grant execute on function public.boha_reception_template_apply(text) to authenticated;

-- Todas as unidades já nascem com o modelo.
insert into public.boha_routines(unit, role_name, block, title, hint, sort)
select u.unit, 'Recepção', t.block, t.title, t.hint, t.sort
from (values ('cb'),('te'),('ma')) as u(unit)
cross join (values
    ('abertura','Conferir a recepção','Balcão organizado e ambiente adequado',1),
    ('abertura','Conferir equipamentos','Computador, telefone e sistema funcionando',2),
    ('abertura','Acessar o Evo','Sistema aberto e disponível',3),
    ('abertura','Conferir mensagens','WhatsApp e demais canais verificados',4),
    ('abertura','Conferir pendências','Identificar o que ficou do turno anterior',5),
    ('abertura','Conferir agenda','Verificar avaliações, visitas e compromissos',6),
    ('atendimento','Recepcionar os alunos com educação e cordialidade',null,7),
    ('atendimento','Cumprimentar e identificar visitantes',null,8),
    ('atendimento','Orientar sobre planos, serviços e funcionamento da academia',null,9),
    ('atendimento','Responder mensagens recebidas',null,10),
    ('atendimento','Atender ligações telefônicas',null,11),
    ('atendimento','Registrar reclamações, sugestões e solicitações',null,12),
    ('atendimento','Acompanhar demandas que dependam de outros colaboradores',null,13),
    ('atendimento','Retornar aos clientes que aguardam respostas',null,14),
    ('vendas','Contatar novos interessados','Realizar contatos com pessoas que demonstraram interesse',15),
    ('vendas','Retomar contatos pendentes','Procurar interessados que ainda não fecharam plano',16),
    ('vendas','Acompanhar avaliações','Conferir interessados que realizaram ou agendaram avaliação',17),
    ('vendas','Apresentar planos','Informar opções, valores e diferenciais',18),
    ('vendas','Registrar vendas','Atualizar o resultado no Evo',19),
    ('vendas','Solicitar indicações','Pedir indicações aos alunos e novos clientes',20),
    ('renovacoes','Conferir alunos com planos próximos do vencimento',null,21),
    ('renovacoes','Realizar contatos de renovação',null,22),
    ('renovacoes','Apresentar as condições de renovação',null,23),
    ('renovacoes','Acompanhar alunos que não responderam',null,24),
    ('renovacoes','Realizar contatos com alunos inativos',null,25),
    ('renovacoes','Registrar os contatos no relacionamento',null,26),
    ('renovacoes','Atualizar o resultado de cada atendimento',null,27),
    ('administrativo','Conferir pagamentos e pendências financeiras',null,28),
    ('administrativo','Verificar alunos inadimplentes',null,29),
    ('administrativo','Realizar cobranças conforme orientação',null,30),
    ('administrativo','Registrar solicitações de cancelamento',null,31),
    ('administrativo','Registrar solicitações de transferência',null,32),
    ('administrativo','Conferir cadastros de novos alunos',null,33),
    ('administrativo','Atualizar informações no sistema',null,34),
    ('administrativo','Registrar ocorrências e situações que precisam de acompanhamento',null,35),
    ('administrativo','Encaminhar demandas administrativas à gestão',null,36),
    ('fechamento','Conferir atendimentos pendentes',null,37),
    ('fechamento','Verificar mensagens sem resposta',null,38),
    ('fechamento','Conferir contatos comerciais que precisam de retorno',null,39),
    ('fechamento','Atualizar tarefas não concluídas',null,40),
    ('fechamento','Registrar ocorrências do expediente',null,41),
    ('fechamento','Organizar a recepção',null,42),
    ('fechamento','Informar à próxima colaboradora as pendências importantes',null,43)
) as t(block,title,hint,sort)
where not exists (select 1 from public.boha_routines r where r.unit = u.unit and r.role_name = 'Recepção' and r.block is not null);

update public.boha_notices set audience = array['admin','gerente','recepcao'],
  body = 'Cada recepcionista recebe automaticamente o checklist completo da recepção (6 blocos, da abertura ao fechamento, com passagem de turno). O gerente acompanha cada pessoa da unidade no painel.'
  where title = 'Novo: Rotina';
