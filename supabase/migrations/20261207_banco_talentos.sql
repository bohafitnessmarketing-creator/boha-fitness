-- Banco de talentos: candidatos enviam o formulário público (link por unidade) e só gerente e administrador veem as respostas.
-- Gerente enxerga apenas candidatos da própria unidade; administrador vê todos.
-- Os dados são pessoais (inclusive de menores): consentimento registrado, prazo de guarda e exclusão pelo gerente.
-- A chave de pontuação fica só no banco (candidatos não conseguem ver as respostas "ideais" no código da página).

create table if not exists public.boha_talent_apps (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  unit text not null check (unit in ('cb','te','ma')),
  vaga text not null default 'recepcao' check (vaga in ('recepcao')),
  name text not null check (char_length(name) between 3 and 120),
  age smallint not null check (age between 14 and 99),
  phone text not null check (phone ~ '^[0-9]{10,11}$'),
  place text not null check (char_length(place) between 2 and 160),
  answers jsonb not null,
  consent_bank boolean not null default false,
  consent_at timestamptz not null default now(),
  status text not null default 'novo' check (status in ('novo','entrevista','banco','contratado','descartado')),
  essay_score smallint check (essay_score is null or essay_score between 0 and 25),
  notes text check (notes is null or char_length(notes) <= 2000),
  reviewed_by text,
  reviewed_at timestamptz,
  keep_until timestamptz not null
);
create index if not exists boha_talent_apps_unit on public.boha_talent_apps(unit, created_at desc);
create index if not exists boha_talent_apps_phone on public.boha_talent_apps(phone, vaga, created_at desc);

-- Controle de abuso (sem acesso para ninguém; só as funções internas leem)
create table if not exists public.boha_talent_rate (
  id bigserial primary key,
  ip_hash text not null,
  unit text,
  at timestamptz not null default now()
);
create index if not exists boha_talent_rate_ip on public.boha_talent_rate(ip_hash, at desc);

alter table public.boha_talent_apps enable row level security;
alter table public.boha_talent_rate enable row level security;
revoke all on public.boha_talent_apps, public.boha_talent_rate from anon, authenticated;
revoke all on sequence public.boha_talent_rate_id_seq from anon, authenticated;
grant select on public.boha_talent_apps to authenticated;

-- Só gerente e administrador, com o módulo liberado, e só da própria unidade (administrador: todas).
create or replace function public.boha_talent_can(u text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('talentos') and public.boha_role() in ('gerente','admin') and public.boha_unit_ok(u)
$$;
revoke all on function public.boha_talent_can(text) from public, anon;
grant execute on function public.boha_talent_can(text) to authenticated;

drop policy if exists talent_read on public.boha_talent_apps;
create policy talent_read on public.boha_talent_apps for select to authenticated
  using (public.boha_talent_can(unit) and keep_until > now());

-- ---------------------------------------------------------------- pontuação (chave só no banco)
-- Índices das alternativas começam em 0, na ordem em que aparecem no formulário.
-- Comunicação e interpretação (20): q11 (10) + q12 (5) + q13 (5)
-- Situações práticas (25): q15 (5), q16 (4), q17 (4), q18 (4), q19 (4), q20 (4)
-- Responsabilidade e comprometimento (20): q30 (12) + q31 (8)
-- Disponibilidade e compatibilidade (10): q8 (6) + q32 (4)
-- Respostas discursivas e maturidade (25): avaliadas pelo gerente (essay_score)
create or replace function public.boha_talent_score(a jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  pick int[];
  com int := 0; pra int := 0; res int := 0; dis int := 0;
  okm jsonb := '{}'::jsonb; n int; v int;
begin
  -- q11 comunicação, q12 computador
  v := (a->>'q11')::int; com := com + coalesce((array[10,7,4,1])[v+1], 0);
  v := (a->>'q12')::int; com := com + coalesce((array[5,4,2,1])[v+1], 0);
  -- q13 ferramentas (7 = nenhuma)
  select coalesce(array_agg(x::int), '{}') into pick from jsonb_array_elements_text(coalesce(a->'q13','[]'::jsonb)) x;
  if 7 = any(pick) then n := 0; else n := least(coalesce(array_length(pick,1),0), 5); end if;
  com := com + n;
  -- situações práticas
  v := (a->>'q15')::int; if v = 1 then pra := pra + 5; end if; okm := okm || jsonb_build_object('q15', v = 1);
  v := (a->>'q16')::int; if v = 2 then pra := pra + 4; end if; okm := okm || jsonb_build_object('q16', v = 2);
  v := (a->>'q17')::int; if v = 2 then pra := pra + 4; end if; okm := okm || jsonb_build_object('q17', v = 2);
  v := (a->>'q18')::int; if v = 0 then pra := pra + 4; end if; okm := okm || jsonb_build_object('q18', v = 0);
  v := (a->>'q19')::int; if v = 2 then pra := pra + 4; end if; okm := okm || jsonb_build_object('q19', v = 2);
  v := (a->>'q20')::int; if v = 0 then pra := pra + 4; end if; okm := okm || jsonb_build_object('q20', v = 0);
  -- responsabilidade
  v := (a->>'q30')::int; res := res + coalesce((array[12,8,4,0])[v+1], 0);
  v := (a->>'q31')::int; res := res + coalesce((array[8,5,1,2])[v+1], 0);
  -- disponibilidade
  v := (a->>'q8')::int; dis := dis + coalesce((array[6,4,2,0])[v+1], 0);
  v := (a->>'q32')::int; dis := dis + coalesce((array[4,3,2,1])[v+1], 0);
  return jsonb_build_object('com', com, 'pra', pra, 'res', res, 'dis', dis, 'auto', com + pra + res + dis, 'ok', okm);
exception when others then
  return jsonb_build_object('com',0,'pra',0,'res',0,'dis',0,'auto',0,'ok','{}'::jsonb);
end $$;
revoke all on function public.boha_talent_score(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- envio pelo candidato (sem login)
create or replace function public.boha_talent_apply(
  p_unit text, p_vaga text, p_name text, p_age int, p_phone text, p_place text,
  p_answers jsonb, p_consent_bank boolean default false, p_hp text default '', p_elapsed int default 0
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone,''), '\D', '', 'g');
  v_name text := regexp_replace(trim(coalesce(p_name,'')), '\s+', ' ', 'g');
  v_place text := trim(coalesce(p_place,''));
  v_hdr jsonb; v_ip text; v_ipf text; k text; val jsonb; q text; n int; v_id uuid; v_first text;
  v_required text[] := array['q5','q6','q7','q8','q9','q10','q11','q12','q13','q14','q15','q16','q17','q18','q19','q20','q21','q22','q23','q24','q25','q26','q27','q28','q29','q30','q31','q32','q34','q35'];
  v_keep timestamptz;
begin
  -- robô (campo escondido preenchido ou formulário enviado rápido demais): finge que deu certo
  if coalesce(p_hp,'') <> '' or coalesce(p_elapsed,0) < 25000 then return 'ok'; end if;
  if p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  if p_vaga <> 'recepcao' then raise exception 'Vaga inválida.'; end if;
  if char_length(v_name) < 3 or char_length(v_name) > 120 then raise exception 'Informe seu nome completo.'; end if;
  if p_age is null or p_age < 14 or p_age > 99 then raise exception 'Idade inválida.'; end if;
  if v_phone !~ '^[0-9]{10,11}$' then raise exception 'Informe um telefone com DDD.'; end if;
  if char_length(v_place) < 2 or char_length(v_place) > 160 then raise exception 'Informe bairro e cidade.'; end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' or pg_column_size(p_answers) > 30000 then raise exception 'Respostas inválidas.'; end if;
  -- respostas obrigatórias presentes e no formato certo
  foreach q in array v_required loop
    if not (p_answers ? q) then raise exception 'Faltou responder uma pergunta obrigatória.'; end if;
  end loop;
  for k, val in select * from jsonb_each(p_answers) loop
    if k !~ '^q[0-9]{1,2}$' then raise exception 'Respostas inválidas.'; end if;
    if jsonb_typeof(val) = 'string' then
      if char_length(val #>> '{}') > 1500 then raise exception 'Uma das respostas ficou longa demais.'; end if;
    elsif jsonb_typeof(val) = 'number' then
      if (val #>> '{}')::numeric not between 0 and 9 or (val #>> '{}')::numeric <> trunc((val #>> '{}')::numeric) then raise exception 'Respostas inválidas.'; end if;
    elsif jsonb_typeof(val) = 'array' then
      if jsonb_array_length(val) > 10 or exists (select 1 from jsonb_array_elements(val) e where jsonb_typeof(e) <> 'number' or (e #>> '{}')::numeric not between 0 and 9) then raise exception 'Respostas inválidas.'; end if;
    else raise exception 'Respostas inválidas.'; end if;
  end loop;
  if jsonb_typeof(p_answers->'q21') <> 'string' or char_length(trim(p_answers->>'q21')) < 3 then raise exception 'Responda as perguntas abertas.'; end if;
  if (p_answers->>'q34') is distinct from '0' or (p_answers->>'q35') is distinct from '0' then
    raise exception 'Sem a sua confirmação e autorização não conseguimos receber a candidatura.';
  end if;
  if jsonb_array_length(p_answers->'q14') <> 3 then raise exception 'Escolha exatamente 3 características.'; end if;

  -- limite por origem (5 por hora, 15 por dia) e por unidade (150 por dia)
  v_hdr := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  v_ipf := coalesce(v_hdr->>'cf-connecting-ip', split_part(coalesce(v_hdr->>'x-forwarded-for',''), ',', 1), 'desconhecido');
  v_ip := md5('boha-talent:' || coalesce(nullif(v_ipf,''),'desconhecido'));
  delete from public.boha_talent_rate where at < now() - interval '2 days';
  if (select count(*) from public.boha_talent_rate where ip_hash = v_ip and at > now() - interval '1 hour') >= 5
     or (select count(*) from public.boha_talent_rate where ip_hash = v_ip and at > now() - interval '1 day') >= 15
     or (select count(*) from public.boha_talent_rate where unit = p_unit and at > now() - interval '1 day') >= 150 then
    raise exception 'Muitos envios em pouco tempo. Tente de novo mais tarde.';
  end if;
  -- mesma pessoa não precisa enviar de novo
  if exists (select 1 from public.boha_talent_apps where phone = v_phone and vaga = p_vaga and created_at > now() - interval '60 days') then
    return 'duplicado';
  end if;

  v_keep := now() + case when coalesce(p_consent_bank,false) then interval '12 months' else interval '6 months' end;
  insert into public.boha_talent_apps(unit, vaga, name, age, phone, place, answers, consent_bank, keep_until)
  values (p_unit, p_vaga, v_name, p_age, v_phone, v_place, p_answers - 'q1' - 'q2' - 'q3' - 'q4', coalesce(p_consent_bank,false), v_keep)
  returning id into v_id;
  insert into public.boha_talent_rate(ip_hash, unit) values (v_ip, p_unit);

  -- avisa no sino os gerentes da unidade e os administradores
  v_first := split_part(v_name, ' ', 1);
  insert into public.boha_notices(title, body, module, audience, created_by, to_email)
  select left('Novo candidato: ' || v_first, 120),
         left('Jovem Aprendiz · Recepção · ' || case p_unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' else 'Macedônia' end || '. Veja as respostas no Banco de talentos.', 300),
         'talentos', array['gerente','admin']::text[], 'Sistema BOHA', a.email
    from public.boha_access a
   where a.role = 'admin' or (a.role = 'gerente' and a.unit = p_unit);
  return 'ok';
end $$;
revoke all on function public.boha_talent_apply(text,text,text,int,text,text,jsonb,boolean,text,int) from public;
grant execute on function public.boha_talent_apply(text,text,text,int,text,text,jsonb,boolean,text,int) to anon, authenticated;

-- ---------------------------------------------------------------- leitura para a gerência (com a nota automática)
create or replace function public.boha_talent_list()
returns table(id uuid, created_at timestamptz, unit text, vaga text, name text, age smallint, phone text, place text,
              answers jsonb, consent_bank boolean, status text, essay_score smallint, notes text, reviewed_by text,
              reviewed_at timestamptz, keep_until timestamptz, score jsonb)
language plpgsql security definer set search_path = '' as $$
begin
  if not (public.boha_can('talentos') and public.boha_role() in ('gerente','admin')) then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;
  delete from public.boha_talent_apps d where d.keep_until <= now();
  return query
    select t.id, t.created_at, t.unit, t.vaga, t.name, t.age, t.phone, t.place, t.answers, t.consent_bank, t.status,
           t.essay_score, t.notes, t.reviewed_by, t.reviewed_at, t.keep_until, public.boha_talent_score(t.answers)
      from public.boha_talent_apps t
     where public.boha_unit_ok(t.unit)
     order by t.created_at desc
     limit 1000;
end $$;
revoke all on function public.boha_talent_list() from public, anon;
grant execute on function public.boha_talent_list() to authenticated;

-- Atualiza etapa, nota das respostas abertas e anotações (só esses campos)
create or replace function public.boha_talent_update(p_id uuid, p_patch jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.boha_talent_apps%rowtype; v_status text; v_essay smallint; v_notes text;
begin
  select * into t from public.boha_talent_apps where id = p_id;
  if not found or not public.boha_talent_can(t.unit) then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  v_status := case when p_patch ? 'status' then p_patch->>'status' else t.status end;
  if v_status not in ('novo','entrevista','banco','contratado','descartado') then raise exception 'Etapa inválida.'; end if;
  if v_status = 'banco' and not t.consent_bank then raise exception 'Este candidato não autorizou guardar os dados no banco de talentos.'; end if;
  v_essay := case when p_patch ? 'essay_score' then nullif(p_patch->>'essay_score','')::smallint else t.essay_score end;
  if v_essay is not null and v_essay not between 0 and 25 then raise exception 'A nota das respostas abertas vai de 0 a 25.'; end if;
  v_notes := case when p_patch ? 'notes' then nullif(left(p_patch->>'notes', 2000), '') else t.notes end;
  update public.boha_talent_apps set status = v_status, essay_score = v_essay, notes = v_notes,
         reviewed_by = lower(auth.jwt()->>'email'), reviewed_at = now() where id = p_id;
end $$;
revoke all on function public.boha_talent_update(uuid,jsonb) from public, anon;
grant execute on function public.boha_talent_update(uuid,jsonb) to authenticated;

-- Excluir o candidato (pedido do titular ou fim do processo)
create or replace function public.boha_talent_delete(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare u text;
begin
  select unit into u from public.boha_talent_apps where id = p_id;
  if u is null or not public.boha_talent_can(u) then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  delete from public.boha_talent_apps where id = p_id;
end $$;
revoke all on function public.boha_talent_delete(uuid) from public, anon;
grant execute on function public.boha_talent_delete(uuid) to authenticated;

-- ---------------------------------------------------------------- módulo na lista de permissões (gerente; administrador tem tudo)
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'talentos')
  where role = 'gerente' and not ('talentos' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Banco de talentos',
  'Envie o link do processo seletivo para quem entregar currículo. As respostas chegam aqui com nota automática, e só gerente e administrador enxergam.',
  'talentos',array['admin','gerente']::text[],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Banco de talentos');
