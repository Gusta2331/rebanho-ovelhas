-- Agrupa vários procedimentos realizados na mesma operação de manejo.
-- O campo é opcional para preservar todos os registros antigos e o fluxo
-- tradicional de um único procedimento.
alter table public.manejos
  add column if not exists operacao_id uuid;

create index if not exists manejos_operacao_id_idx
  on public.manejos(operacao_id)
  where operacao_id is not null;
