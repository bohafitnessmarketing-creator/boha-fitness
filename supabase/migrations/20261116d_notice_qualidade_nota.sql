insert into public.boha_notices(title,body,module,audience,created_by)
select 'Qualidade dos professores: nova nota e % da unidade',
  'Cada professor agora mostra a parte das respostas da unidade (ex.: 13,2%) e uma nota de 0 a 100 (regular neutro, ruim e péssimo descontam), ajustada para poucas respostas. O Funcionário do mês passa a ser por nota, só com 10+ respostas, e aparece ⚠ quando ruim/péssimo passam de 10%.',
  'qualidade',array['admin'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Qualidade dos professores: nova nota e % da unidade');
