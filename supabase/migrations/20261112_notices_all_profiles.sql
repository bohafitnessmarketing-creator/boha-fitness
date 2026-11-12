drop policy if exists notices_read on public.boha_notices;
create policy notices_read on public.boha_notices
  for select to authenticated
  using (
    public.boha_role() is not null
    and (audience is null or cardinality(audience) = 0 or public.boha_role() = any(audience))
  );
