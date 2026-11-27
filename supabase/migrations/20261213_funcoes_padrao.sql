-- Padroniza as funções já cadastradas que têm correspondência inequívoca com a nova lista do Banco de funcionários
-- (Gerente, Recepcionista, Estagiário, Professor de aulas coletivas, Professor de sala).
-- Professores e demais cargos antigos ficam como estão até alguém escolher a função exata no cadastro.
update public.boha_employees set title = case
  when lower(trim(title)) in ('estagiario','estagiário') then 'Estagiário'
  when lower(trim(title)) in ('recepção','recepcao') then 'Recepcionista'
  when lower(trim(title)) = 'gerente' then 'Gerente'
  when title = 'System.Xml.XmlElement' then '' end
where lower(trim(title)) in ('estagiario','estagiário','recepção','recepcao','gerente') or title = 'System.Xml.XmlElement';
