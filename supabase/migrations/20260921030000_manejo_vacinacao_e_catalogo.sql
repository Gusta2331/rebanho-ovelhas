-- Dados específicos de vacinação e catálogo de vacinas.
-- Seguro para bancos que já possuem a tabela manejos.

create table if not exists public.vacinas (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  nome text not null,
  fabricante text,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_vacinas_fazenda
  on public.vacinas(fazenda_id);

create index if not exists idx_vacinas_ativo
  on public.vacinas(fazenda_id, ativo);

alter table public.manejos
  add column if not exists vacina_id uuid references public.vacinas(id) on delete set null;

alter table public.manejos
  add column if not exists vacina_nome text;

alter table public.manejos
  add column if not exists vacina_fabricante text;

alter table public.manejos
  add column if not exists vacina_lote text;

alter table public.manejos_programados
  add column if not exists vacina_id uuid references public.vacinas(id) on delete set null;

alter table public.manejos_programados
  add column if not exists vacina_nome text;

alter table public.manejos_programados
  add column if not exists vacina_fabricante text;

alter table public.vacinas enable row level security;

drop policy if exists "vacinas_select_proprietario" on public.vacinas;
create policy "vacinas_select_proprietario"
on public.vacinas
for select
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = vacinas.fazenda_id
      and f.proprietario_id = auth.uid()
  )
);

drop policy if exists "vacinas_insert_proprietario" on public.vacinas;
create policy "vacinas_insert_proprietario"
on public.vacinas
for insert
with check (
  exists (
    select 1
    from public.fazendas f
    where f.id = vacinas.fazenda_id
      and f.proprietario_id = auth.uid()
  )
);

drop policy if exists "vacinas_update_proprietario" on public.vacinas;
create policy "vacinas_update_proprietario"
on public.vacinas
for update
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = vacinas.fazenda_id
      and f.proprietario_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.fazendas f
    where f.id = vacinas.fazenda_id
      and f.proprietario_id = auth.uid()
  )
);

drop policy if exists "vacinas_delete_proprietario" on public.vacinas;
create policy "vacinas_delete_proprietario"
on public.vacinas
for delete
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = vacinas.fazenda_id
      and f.proprietario_id = auth.uid()
  )
);
