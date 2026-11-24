-- Pautas já criadas nas datas comemorativas fitness (2026-12 a 2027-12), uma por unidade (cada unidade tem o próprio Instagram).
-- Idempotente: não duplica se a unidade já tiver pauta com o mesmo título no mesmo dia. Status "ideia", canal Instagram.
insert into public.boha_editorial_items (unit, planned_date, channel, title, status)
select u.unit, d.planned_date::date, 'Instagram', d.title, 'idea'
from (values ('cb'),('te'),('ma')) as u(unit)
cross join (values
  ('2026-12-21','Dia Nacional do Atleta + Início do verão'),
  ('2026-12-31','Corrida de São Silvestre'),
  ('2027-02-06','Dia Mundial do Muay Thai'),
  ('2027-02-10','Dia do Atleta Profissional'),
  ('2027-02-19','Dia do Esportista'),
  ('2027-03-10','Dia de Combate ao Sedentarismo'),
  ('2027-03-31','Dia da Saúde e Nutrição'),
  ('2027-04-06','Dia Mundial da Atividade Física + Dia Internacional do Esporte'),
  ('2027-04-07','Dia Mundial da Saúde'),
  ('2027-04-29','Dia Internacional da Dança'),
  ('2027-05-26','Dia do Desafio'),
  ('2027-06-02','Dia Mundial da Corrida'),
  ('2027-06-03','Dia Mundial da Bicicleta'),
  ('2027-06-12','Dia Mundial do Bem-Estar'),
  ('2027-06-21','Dia Internacional do Yoga'),
  ('2027-06-23','Dia Nacional do Esporte + Dia Olímpico'),
  ('2027-07-19','Dia Nacional do Futebol'),
  ('2027-08-05','Dia Nacional da Saúde'),
  ('2027-08-31','Dia do Nutricionista'),
  ('2027-09-01','Dia do Profissional de Educação Física'),
  ('2027-09-08','Dia Mundial da Fisioterapia'),
  ('2027-09-22','Dia Nacional do Atleta Paralímpico'),
  ('2027-10-13','Dia do Fisioterapeuta'),
  ('2027-10-30','Dia do Fisiculturista'),
  ('2027-12-21','Dia Nacional do Atleta + Início do verão'),
  ('2027-12-31','Corrida de São Silvestre')
) as d(planned_date, title)
where not exists (
  select 1 from public.boha_editorial_items i
  where i.unit = u.unit and i.planned_date = d.planned_date::date and i.title = d.title
);
