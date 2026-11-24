-- Remove o campo de passagem de turno da Rotina da recepção (a tarefa de avisar o próximo do plantão continua no checklist).
update public.boha_routines set hint = 'Avisar quem entra: pendências, retornos e ocorrências'
  where role_name = 'Recepção' and title = 'Verificar atendimentos pendentes e passar a informação ao próximo do plantão';
create or replace function public.boha_reception_template_apply(p_unit text) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer := 0;
begin
  if p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  if not (public.boha_can('rotina') and public.boha_role() = any (array['admin','gerente','dono','marketing']) and public.boha_unit_ok(p_unit)) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  if exists (select 1 from public.boha_routines where unit = p_unit and role_name = 'Recepção' and block is not null) then return 0; end if;
  insert into public.boha_routines(unit, role_name, block, title, hint, sort)
  select p_unit, 'Recepção', t.block, t.title, t.hint, t.sort from (values
    ('abertura','Verificar o ambiente de trabalho e os equipamentos','Recepção organizada; computador, telefone e Evo funcionando',1),
    ('abertura','Verificar as mensagens pendentes de resposta','WhatsApp e demais canais, mais o que ficou do turno anterior',2),
    ('abertura','Repostar os stories e verificar o Instagram',null,3),
    ('atendimento','Identificar e orientar visitantes','Planos, serviços e funcionamento. Nenhum cliente fica sem atendimento',4),
    ('atendimento','Registrar solicitações, reclamações e ocorrências','Nada fica só na conversa: tudo registrado',5),
    ('atendimento','Encaminhar demandas que dependem de outros setores','Acompanhar até ter retorno',6),
    ('vendas','Contatar alunos próximos da renovação e com inadimplência','Registrar o contato e o resultado',7),
    ('vendas','Enviar boas-vindas aos novos alunos e aniversariantes','Conferir as matrículas do dia anterior',8),
    ('vendas','Acompanhar interessados e registrar as vendas no Evo','Todo interessado com contato, resultado e próxima ação registrados',9),
    ('administrativo','Conferir pagamentos e situações de inadimplência',null,10),
    ('administrativo','Registrar solicitações de cancelamento e transferência','Nada fica só em conversa verbal ou mensagem',11),
    ('fechamento','Fechar o caixa (encerramento do expediente)',null,12),
    ('fechamento','Verificar atendimentos pendentes e passar a informação ao próximo do plantão','Avisar quem entra: pendências, retornos e ocorrências',13),
    ('fechamento','Organizar a recepção',null,14)
  ) as t(block,title,hint,sort);
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.boha_reception_template_apply(text) from public, anon;
grant execute on function public.boha_reception_template_apply(text) to authenticated;
update public.boha_notices set body = 'Checklist da recepção enxuto: 14 tarefas em 5 blocos, da abertura ao fechamento. Cada recepcionista já recebe ao ganhar acesso e o gerente acompanha no painel.'
  where title = 'Novo: Rotina';
