-- Criação de artes liberada também para a recepção (cada pessoa com 5 artes por dia, só da própria unidade).
-- A restrição por unidade e o histórico individual já valem para qualquer perfil com o módulo.
update public.boha_role_modules set modules = array_append(modules,'artes')
  where role = 'recepcao' and not ('artes' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Criação de artes liberada para a recepção',
  'Escreva o texto e o objetivo do post, escolha o formato e o sistema monta a arte com o logo da Boha. São 5 artes por pessoa por dia, sempre da sua unidade.',
  'artes',array['recepcao']::text[],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Criação de artes liberada para a recepção');
