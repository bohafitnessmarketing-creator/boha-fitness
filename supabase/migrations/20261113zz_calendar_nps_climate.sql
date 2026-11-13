-- Professores: cada rodada mantém seu próprio mês; as linhas atuais são de novembro de 2026.
alter table public.boha_professor_ratings
  add column if not exists survey_month date not null default date '2026-11-01';
alter table public.boha_professor_ratings
  drop constraint if exists boha_professor_ratings_unit_professor_key;
alter table public.boha_professor_ratings
  add constraint boha_professor_ratings_unit_professor_month_key unique(unit,professor,survey_month);

create table if not exists public.boha_climate_responses (
  id uuid primary key default gen_random_uuid(),
  survey_month date not null default date '2026-09-01',
  submitted_at timestamptz not null,
  unit text not null check (unit in ('cb','te','ma')),
  job_role text not null default '' check (length(job_role) <= 120),
  answers jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists boha_climate_responses_month_unit on public.boha_climate_responses(survey_month,unit,submitted_at);
alter table public.boha_climate_responses enable row level security;
revoke all on public.boha_climate_responses from anon;
grant select,insert,update,delete on public.boha_climate_responses to authenticated;
drop policy if exists climate_module_access on public.boha_climate_responses;
create policy climate_module_access on public.boha_climate_responses for all to authenticated
  using (public.boha_can('clima')) with check (public.boha_can('clima'));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Ranking mensal de professores',
  'O ranking agora separa cada mês. O primeiro critério é o número de respostas; em caso de empate, conta o total de avaliações “ótimo”.',
  'qualidade',array['admin'],'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Ranking mensal de professores');
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Calendário editorial disponível',
  'Organize pautas por unidade, data e canal, atribua uma pessoa da equipe e acompanhe o status da publicação.',
  'calendario',array['admin'],'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Calendário editorial disponível');
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Pesquisa de NPS disponível',
  'Registre respostas anônimas de 0 a 10 e acompanhe promotores, neutros e detratores por unidade.',
  'nps',array['admin'],'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Pesquisa de NPS disponível');
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Pesquisa de clima de setembro',
  'O novo painel organiza as respostas por unidade, função e pergunta. Comentários internos ficam visíveis apenas a perfis liberados em Gestão de acessos.',
  'clima',array['admin'],'Sistema BOHA'
where not exists(select 1 from public.boha_notices where title='Pesquisa de clima de setembro');
