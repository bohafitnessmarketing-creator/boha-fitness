-- NPS e Clima: perfis liberados no módulo leem (e o NPS aceita novas respostas);
-- só administrador altera ou apaga. A resposta de NPS não guarda mais quem a digitou.
alter table public.boha_nps_responses drop column if exists created_by;

drop policy if exists nps_module_access on public.boha_nps_responses;
drop policy if exists nps_read on public.boha_nps_responses;
drop policy if exists nps_insert on public.boha_nps_responses;
drop policy if exists nps_admin_update on public.boha_nps_responses;
drop policy if exists nps_admin_delete on public.boha_nps_responses;
create policy nps_read on public.boha_nps_responses for select to authenticated using (public.boha_can('nps'));
create policy nps_insert on public.boha_nps_responses for insert to authenticated with check (public.boha_can('nps'));
create policy nps_admin_update on public.boha_nps_responses for update to authenticated using (public.boha_is_admin()) with check (public.boha_is_admin());
create policy nps_admin_delete on public.boha_nps_responses for delete to authenticated using (public.boha_is_admin());

drop policy if exists climate_module_access on public.boha_climate_responses;
drop policy if exists climate_read on public.boha_climate_responses;
drop policy if exists climate_admin_insert on public.boha_climate_responses;
drop policy if exists climate_admin_update on public.boha_climate_responses;
drop policy if exists climate_admin_delete on public.boha_climate_responses;
create policy climate_read on public.boha_climate_responses for select to authenticated using (public.boha_can('clima'));
create policy climate_admin_insert on public.boha_climate_responses for insert to authenticated with check (public.boha_is_admin());
create policy climate_admin_update on public.boha_climate_responses for update to authenticated using (public.boha_is_admin()) with check (public.boha_is_admin());
create policy climate_admin_delete on public.boha_climate_responses for delete to authenticated using (public.boha_is_admin());
