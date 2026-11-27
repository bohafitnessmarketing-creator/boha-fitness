-- A Hierarquia passa a refletir o Banco de funcionários; a função do cadastro também define o checklist (Rotina por função).
-- Quem tem login com o mesmo nome do cadastro recebe o checklist da função do cadastro (além das posições nomeadas na Hierarquia).
create or replace function public.boha_placements() returns table(email text, name text, unit text, fn text)
language sql stable security definer set search_path = '' as $$
  with nodes as (
    select m.id as node_id, public.boha_norm(m.data->>'name') as nm,
      coalesce(o.role, case regexp_replace(regexp_replace(m.id,'^(cb|te|ma)-',''),'[0-9]+$','') when 'professora' then 'professor' else regexp_replace(regexp_replace(m.id,'^(cb|te|ma)-',''),'[0-9]+$','') end) as fn,
      coalesce(o.scope, case when m.id ~ '^(cb|te|ma)-' then substr(m.id,1,2) end) as unit
    from public.boha_members m
    left join public.boha_org_nodes o on o.id = m.id and o.op = 'add'
    where coalesce(m.data->>'name','') <> ''
      and not exists (select 1 from public.boha_org_nodes h where h.id = m.id and h.op = 'hide')
    union all
    select e.id::text, public.boha_norm(e.name),
      case when public.boha_norm(e.title) ~ 'gerente' then (case when e.unit = 'rede' then 'geral' else 'gerente' end)
           when public.boha_norm(e.title) ~ 'recep' then 'recepcao'
           when public.boha_norm(e.title) ~ 'estagi' then 'estagiaria'
           when public.boha_norm(e.title) ~ 'limpez' then 'limpeza'
           when public.boha_norm(e.title) ~ 'manuten' then 'manutencao'
           when public.boha_norm(e.title) ~ 'market' then 'conteudo'
           when public.boha_norm(e.title) ~ 'financ' then 'financeiro'
           when public.boha_norm(e.title) ~ 'administr|\mrh\M' then 'rh'
           when public.boha_norm(e.title) ~ 'professor|zumba|pilates|jump|luta|boxe|fit ?dance|sertanej|danca|spinning|aula' then 'professor' end,
      case when e.unit = 'rede' then null else e.unit end
    from public.boha_employees e where e.status = 'active'
  )
  select distinct a.email, a.name, n.unit, n.fn
    from nodes n join public.boha_access a on public.boha_norm(a.name) = n.nm and a.role <> 'admin'
   where n.fn in ('direcao','geral','financeiro','manutencao','rh','conteudo','campanhas','gerente','tecnico','professor','liderrecepcao','recepcao','limpeza','estagiaria')
$$;
revoke all on function public.boha_placements() from public, anon, authenticated;
