-- Mural único da rede (a arte é a mesma para as 3 unidades).
-- A coluna unit continua existindo: 'rede' = mural único; cb/te/ma ficam reservados para murais por unidade no futuro.
alter table public.boha_mural_slots drop constraint if exists boha_mural_slots_unit_check;
alter table public.boha_mural_slots add constraint boha_mural_slots_unit_check check (unit in ('rede','cb','te','ma'));
alter table public.boha_mural_slots alter column unit set default 'rede';
update public.boha_notices
  set body='O quadro de avisos agora tem versão digital, um só para a rede. Escolha o mês, toque numa folha para anexar a foto (ou arraste a imagem) e use a nota para planejar o mês seguinte.'
  where title='Novo: Mural do mês';
