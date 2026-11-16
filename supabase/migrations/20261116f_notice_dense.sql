insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo botão: versão reduzida dos módulos',
  'No computador, o botão de grade ao lado de "Áreas do sistema" alterna entre a visão normal e a reduzida, que mostra todos os módulos de uma vez. O navegador lembra a sua escolha.',
  null,array['admin','dono','gerente','marketing','recepcao'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo botão: versão reduzida dos módulos');
