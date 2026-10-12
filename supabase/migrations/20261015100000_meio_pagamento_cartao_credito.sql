-- Identifica o meio de pagamento sem alterar o histórico Pix existente.
alter table public.pagamentos_planos
  add column if not exists metodo text not null default 'pix';

alter table public.pagamentos_planos
  drop constraint if exists pagamentos_planos_metodo_check;

alter table public.pagamentos_planos
  add constraint pagamentos_planos_metodo_check
  check (metodo in ('pix', 'cartao_credito'));

notify pgrst, 'reload schema';
