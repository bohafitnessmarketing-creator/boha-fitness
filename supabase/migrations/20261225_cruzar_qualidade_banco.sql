-- Cruza as avaliações de professores (Qualidade) com o Banco de funcionários para a foto vir do cadastro.
-- 1) A comparação de nomes ignora acento, maiúsculas, espaços duplos e qualquer sufixo entre parênteses: "ERICA  NASCIMENTO (ST)" = "Erica Nascimento".
create or replace function public.boha_norm(t text) returns text language sql immutable set search_path = '' as $$
  select regexp_replace(trim(regexp_replace(translate(lower(coalesce(t,'')),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'\s*\([^)]*\)\s*$','')),'\s+',' ','g')
$$;

-- 2) Nome igual: liga (mesma unidade primeiro, depois quem tem foto).
update public.boha_professor_ratings r set employee_id = (
  select e.id from public.boha_employees e where public.boha_norm(e.name) = public.boha_norm(r.professor)
  order by (e.unit = r.unit) desc, (e.photo_path is not null) desc, (e.status = 'active') desc, e.created_at limit 1)
where r.employee_id is null;

-- 3) Nome parecido (um contém o outro, com pelo menos 2 nomes) na MESMA unidade, só quando há uma única pessoa possível.
update public.boha_professor_ratings r set employee_id = x.id
from (
  select r2.id as rid, (array_agg(e.id order by (e.photo_path is not null) desc))[1] as id
  from public.boha_professor_ratings r2
  join public.boha_employees e on e.unit = r2.unit and e.status = 'active'
   and cardinality(string_to_array(public.boha_norm(r2.professor),' ')) >= 2 and cardinality(string_to_array(public.boha_norm(e.name),' ')) >= 2
   and (string_to_array(public.boha_norm(r2.professor),' ') <@ string_to_array(public.boha_norm(e.name),' ')
     or string_to_array(public.boha_norm(e.name),' ') <@ string_to_array(public.boha_norm(r2.professor),' '))
  where r2.employee_id is null
  group by r2.id having count(distinct public.boha_norm(e.name)) = 1
) x where r.id = x.rid and r.employee_id is null;
