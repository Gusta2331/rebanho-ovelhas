-- Registra cobranças de planos sem expor credenciais do Mercado Pago ao aplicativo.
create table if not exists public.pagamentos_planos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete restrict,
  plano_id text not null references public.planos_produtor(id) on delete restrict,
  valor numeric(10,2) not null check (valor > 0),
  provedor text not null default 'mercado_pago',
  provedor_order_id text unique,
  status text not null default 'criado'
    check (status in ('criado', 'pendente', 'aprovado', 'rejeitado', 'cancelado', 'erro')),
  qr_code text,
  qr_code_base64 text,
  ticket_url text,
  expira_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists pagamentos_planos_usuario_criado_idx
  on public.pagamentos_planos (usuario_id, criado_em desc);

alter table public.pagamentos_planos enable row level security;

drop policy if exists "Usuário consulta seus pagamentos de plano" on public.pagamentos_planos;
create policy "Usuário consulta seus pagamentos de plano"
  on public.pagamentos_planos
  for select
  to authenticated
  using (auth.uid() = usuario_id);

-- Não são concedidas permissões de INSERT/UPDATE ao cliente. A Edge Function
-- usa service_role para registrar a cobrança e somente o backend pode alterá-la.
