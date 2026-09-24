-- Registra quando a prenhez foi efetivamente confirmada.
-- A data da cobertura continua representando a monta, enquanto esta data
-- representa a confirmação da gestação.
alter table public.reproducoes
  add column if not exists data_confirmacao_prenhez date;
