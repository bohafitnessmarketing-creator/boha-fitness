-- Mural do mês: 8 folhas por unidade e mês, cada uma com foto e nota de planejamento.
create table if not exists public.boha_mural_slots (
  id uuid primary key default gen_random_uuid(),
  unit text not null check (unit in ('cb','te','ma')),
  month date not null check (month = date_trunc('month', month)::date),
  slot smallint not null check (slot between 1 and 8),
  photo_path text check (photo_path is null or photo_path ~ '^[a-z0-9-]{8,80}\.jpg$'),
  note text not null default '' check (char_length(note) <= 200),
  updated_by text default lower(auth.jwt()->>'email'),
  updated_at timestamptz not null default now(),
  unique (unit, month, slot)
);
create index if not exists boha_mural_slots_month on public.boha_mural_slots(month, unit);
alter table public.boha_mural_slots enable row level security;
revoke all on public.boha_mural_slots from anon;
grant select, insert, update, delete on public.boha_mural_slots to authenticated;
drop policy if exists mural_slots_access on public.boha_mural_slots;
create policy mural_slots_access on public.boha_mural_slots for all to authenticated
  using (public.boha_can('mural')) with check (public.boha_can('mural'));
create or replace function public.boha_mural_stamp() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := coalesce(lower(auth.jwt()->>'email'), new.updated_by); return new; end $$;
drop trigger if exists boha_mural_stamp on public.boha_mural_slots;
create trigger boha_mural_stamp before insert or update on public.boha_mural_slots for each row execute function public.boha_mural_stamp();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boha-mural','boha-mural',false,4194304,array['image/jpeg']::text[])
on conflict (id) do update set public=false, file_size_limit=4194304, allowed_mime_types=array['image/jpeg']::text[];
drop policy if exists mural_img_read on storage.objects;
drop policy if exists mural_img_insert on storage.objects;
drop policy if exists mural_img_update on storage.objects;
drop policy if exists mural_img_delete on storage.objects;
create policy mural_img_read on storage.objects for select to authenticated using (bucket_id='boha-mural' and public.boha_can('mural'));
create policy mural_img_insert on storage.objects for insert to authenticated with check (bucket_id='boha-mural' and public.boha_can('mural'));
create policy mural_img_update on storage.objects for update to authenticated using (bucket_id='boha-mural' and public.boha_can('mural')) with check (bucket_id='boha-mural' and public.boha_can('mural'));
create policy mural_img_delete on storage.objects for delete to authenticated using (bucket_id='boha-mural' and public.boha_can('mural'));

-- Módulo "mural" entra na lista de permissões por perfil.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
-- Ponto de partida: gerente e marketing planejam o mural. O administrador ajusta em Gestão de acessos.
update public.boha_role_modules set modules = array_append(modules,'mural')
  where role in ('gerente','marketing') and not ('mural' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Mural do mês',
  'O quadro de avisos de cada unidade agora tem versão digital. Escolha a unidade e o mês, toque numa folha para anexar a foto (ou arraste a imagem) e use a nota para planejar o mês seguinte.',
  'mural',array['admin','gerente','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Mural do mês');
