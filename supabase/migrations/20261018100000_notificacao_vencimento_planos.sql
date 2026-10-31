-- Notificações automáticas de vencimento dos planos.
-- A rotina diária roda às 12:00 UTC (09:00 no horário de Brasília).
-- A chave já usada pelos alertas da farmácia é reutilizada; nenhuma credencial
-- fica gravada nesta migration.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema net;

create table if not exists public.notificacoes_planos_enviadas (
  id uuid primary key default gen_random_uuid(),
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  validade_em timestamptz not null,
  tipo text not null default 'vencimento_plano',
  status text not null default 'processando'
    check (status in ('processando', 'enviado', 'erro')),
  tentativas integer not null default 1 check (tentativas > 0),
  enviados integer not null default 0 check (enviados >= 0),
  erro text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  enviado_em timestamptz,
  constraint notificacoes_planos_envio_unico
    unique (fazenda_id, validade_em, tipo)
);

create index if not exists notificacoes_planos_status_idx
  on public.notificacoes_planos_enviadas(status, atualizado_em);

-- Controle por dispositivo: se um celular receber e outro falhar, a próxima
-- tentativa envia somente aos dispositivos que ainda não receberam.
create table if not exists public.notificacoes_planos_dispositivos (
  id uuid primary key default gen_random_uuid(),
  notificacao_id uuid not null
    references public.notificacoes_planos_enviadas(id) on delete cascade,
  dispositivo_id text not null,
  status text not null default 'processando'
    check (status in ('processando', 'enviado', 'erro')),
  tentativas integer not null default 1 check (tentativas > 0),
  erro text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  enviado_em timestamptz,
  constraint notificacoes_planos_dispositivo_unico
    unique (notificacao_id, dispositivo_id)
);

create index if not exists notificacoes_planos_dispositivos_status_idx
  on public.notificacoes_planos_dispositivos(notificacao_id, status);

alter table public.notificacoes_planos_enviadas enable row level security;
alter table public.notificacoes_planos_dispositivos enable row level security;
revoke all on public.notificacoes_planos_enviadas from public, anon, authenticated;
revoke all on public.notificacoes_planos_dispositivos from public, anon, authenticated;

-- Dispara a Edge Function usando o segredo já cadastrado no Vault para os
-- alertas da farmácia. A função nova valida o cabeçalho apikey.
create or replace function public.disparar_notificacao_vencimento_planos()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault, net
as $$
declare
  v_secret text;
  v_request_id bigint;
begin
  select decrypted_secret
    into v_secret
  from vault.decrypted_secrets
  where name = 'ovigestao_service_role_key'
  limit 1;

  if v_secret is null or v_secret = '' then
    raise warning 'Secret ovigestao_service_role_key não encontrado no Vault.';
    return;
  end if;

  select net.http_post(
    url := 'https://ezbfjgozqwzricjwxtba.supabase.co/functions/v1/planos-alerta-vencimento',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_secret
    ),
    body := jsonb_build_object('origem', 'cron'),
    timeout_milliseconds := 15000
  )
  into v_request_id;

  raise log 'Verificação de vencimento de planos enfileirada. request_id=%', v_request_id;
exception
  when others then
    raise warning 'Falha ao enfileirar verificação de vencimento de planos: %', sqlerrm;
end;
$$;

revoke all on function public.disparar_notificacao_vencimento_planos()
  from public, anon, authenticated;

-- Evita criar agendamentos duplicados ao reaplicar a migration.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'ovigestao-alerta-vencimento-planos') then
    perform cron.unschedule('ovigestao-alerta-vencimento-planos');
  end if;

  perform cron.schedule(
    'ovigestao-alerta-vencimento-planos',
    '0 12 * * *',
    'select public.disparar_notificacao_vencimento_planos();'
  );
end $$;

notify pgrst, 'reload schema';
