-- Funções do Banco de funcionários em MAIÚSCULAS, com Auxiliar de limpeza e Manutenção na lista.
update public.boha_employees set title = case
  when lower(trim(title)) in ('estagiario','estagiário') then 'ESTAGIÁRIO'
  when lower(trim(title)) in ('recepcionista','recepção','recepcao') then 'RECEPCIONISTA'
  when lower(trim(title)) = 'gerente' then 'GERENTE'
  when lower(trim(title)) in ('limpeza','auxiliar de limpeza') then 'AUXILIAR DE LIMPEZA'
  when lower(trim(title)) in ('manutenção','manutencao') then 'MANUTENÇÃO'
  when lower(trim(title)) in ('professor de aulas coletivas') then 'PROFESSOR DE AULAS COLETIVAS'
  when lower(trim(title)) in ('professor de sala') then 'PROFESSOR DE SALA' end
where lower(trim(title)) in ('estagiario','estagiário','recepcionista','recepção','recepcao','gerente','limpeza','auxiliar de limpeza','manutenção','manutencao','professor de aulas coletivas','professor de sala');
