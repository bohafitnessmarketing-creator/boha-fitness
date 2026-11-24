-- Uma pauta pode valer para várias unidades (um calendário só, com etiquetas das unidades).
alter table public.boha_editorial_items add column if not exists units text[] not null default '{}';
update public.boha_editorial_items set units = array[unit] where cardinality(units) = 0;
alter table public.boha_editorial_items drop constraint if exists boha_editorial_items_units_valid;
alter table public.boha_editorial_items add constraint boha_editorial_items_units_valid
  check (cardinality(units) between 1 and 3 and units <@ array['cb','te','ma']::text[]);

-- "unit" continua existindo como unidade principal (a primeira). Mantém os dois campos coerentes,
-- inclusive para telas antigas que ainda mandem só "unit".
create or replace function public.boha_editorial_units_sync() returns trigger language plpgsql as $$
begin
  if cardinality(coalesce(new.units,'{}')) = 0 then
    new.units := array[new.unit];
  elsif tg_op = 'UPDATE' and new.unit is distinct from old.unit and new.units = old.units then
    new.units := array[new.unit];
  end if;
  new.units := (select coalesce(array_agg(u order by case u when 'cb' then 1 when 'te' then 2 else 3 end), '{}') from (select distinct unnest(new.units) u) x);
  new.unit := new.units[1];
  return new;
end $$;
drop trigger if exists boha_editorial_units_sync on public.boha_editorial_items;
create trigger boha_editorial_units_sync before insert or update on public.boha_editorial_items
  for each row execute function public.boha_editorial_units_sync();

-- Junta as pautas de datas fitness que foram criadas uma por unidade: fica uma só, com as 3 unidades.
-- Só junta quando as três cópias estão intocadas (sem texto, link, responsável, anexo ou mudança de status).
do $$
declare g record; keep uuid;
begin
  for g in
    select planned_date, title from public.boha_editorial_items i
    where i.channel = 'Instagram' and i.status = 'idea' and i.caption = '' and i.link is null and i.employee_id is null
      and cardinality(i.units) = 1
      and not exists (select 1 from public.boha_editorial_files f where f.item_id = i.id)
    group by planned_date, title
    having count(*) = 3 and count(distinct unit) = 3
  loop
    select id into keep from public.boha_editorial_items where planned_date = g.planned_date and title = g.title and unit = 'cb' and cardinality(units) = 1 limit 1;
    delete from public.boha_editorial_items where planned_date = g.planned_date and title = g.title and unit in ('te','ma') and cardinality(units) = 1;
    update public.boha_editorial_items set units = array['cb','te','ma'] where id = keep;
  end loop;
end $$;
