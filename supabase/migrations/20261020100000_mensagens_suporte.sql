-- Centraliza o contato de suporte e mantém anexos em um bucket privado.
create table if not exists public.mensagens_suporte (
  id uuid primary key,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('bug', 'sugestao', 'duvida', 'outro')),
  assunto text not null,
  mensagem text not null,
  anexos text[] not null default '{}',
  criado_em timestamptz not null default now(),
  notificacao_enviada_em timestamptz,
  notificacao_erro text
);

create index if not exists mensagens_suporte_usuario_criado_idx
  on public.mensagens_suporte (usuario_id, criado_em desc);

alter table public.mensagens_suporte enable row level security;

drop policy if exists "Usuários podem enviar mensagens de suporte" on public.mensagens_suporte;
create policy "Usuários podem enviar mensagens de suporte"
  on public.mensagens_suporte
  for insert to authenticated
  with check (usuario_id = auth.uid());

drop policy if exists "Usuários podem consultar suas mensagens de suporte" on public.mensagens_suporte;
create policy "Usuários podem consultar suas mensagens de suporte"
  on public.mensagens_suporte
  for select to authenticated
  using (usuario_id = auth.uid());

revoke all on public.mensagens_suporte from anon;
grant insert, select on public.mensagens_suporte to authenticated;
grant all on public.mensagens_suporte to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-attachments',
  'support-attachments',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "Usuários enviam seus próprios anexos de suporte" on storage.objects;
create policy "Usuários enviam seus próprios anexos de suporte"
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'support-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Usuários leem seus próprios anexos de suporte" on storage.objects;
create policy "Usuários leem seus próprios anexos de suporte"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'support-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Usuários removem seus próprios anexos de suporte" on storage.objects;
create policy "Usuários removem seus próprios anexos de suporte"
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'support-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

notify pgrst, 'reload schema';
