-- Uma pessoa pode ter mais de um cadastro na mesma unidade quando exerce funções diferentes
-- (ex.: recepcionista e estagiário, ou professor de aulas coletivas). A unicidade passa a ser nome + unidade + função.
alter table public.boha_employees drop constraint if exists boha_employees_unit_name_key;
alter table public.boha_employees add constraint boha_employees_unit_name_title_key unique (unit, name, title);
