-- Permite regravar o PNG final da própria arte (ajustes de texto sem gastar nova geração).
drop policy if exists artes_update on storage.objects;
create policy artes_update on storage.objects for update to authenticated
  using (bucket_id='boha-artes' and public.boha_can('artes') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id='boha-artes' and public.boha_can('artes') and (storage.foldername(name))[1] = auth.uid()::text);
