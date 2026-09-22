-- Ampliação do módulo sanitário: doses, vias, carência, vermífugos,
-- medicamentos e peso usado para calcular doses.

alter table public.manejos
  add column if not exists peso_kg numeric(10,2);

alter table public.manejos
  add column if not exists dose numeric(10,3);

alter table public.manejos
  add column if not exists dose_unidade text;

alter table public.manejos
  add column if not exists peso_referencia_kg numeric(10,2);

alter table public.manejos
  add column if not exists via_aplicacao text;

alter table public.manejos
  add column if not exists validade date;

alter table public.manejos
  add column if not exists carencia_dias integer;

create table if not exists public.vermifugos (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  nome text not null,
  principio_ativo text,
  concentracao text,
  dose numeric(10,3),
  dose_unidade text,
  peso_referencia_kg numeric(10,2),
  via_aplicacao text,
  carencia_dias integer,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.medicamentos (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  nome text not null,
  principio_ativo text,
  concentracao text,
  dose numeric(10,3),
  dose_unidade text,
  peso_referencia_kg numeric(10,2),
  via_aplicacao text,
  carencia_dias integer,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.vacinas
  add column if not exists dose numeric(10,3);

alter table public.vacinas
  add column if not exists dose_unidade text;

alter table public.vacinas
  add column if not exists peso_referencia_kg numeric(10,2);

alter table public.vacinas
  add column if not exists via_aplicacao text;

alter table public.vacinas
  add column if not exists carencia_dias integer;

alter table public.vacinas
  add column if not exists observacoes text;

alter table public.manejos_programados
  add column if not exists dose numeric(10,3);

alter table public.manejos_programados
  add column if not exists dose_unidade text;

alter table public.manejos_programados
  add column if not exists peso_referencia_kg numeric(10,2);

alter table public.manejos_programados
  add column if not exists via_aplicacao text;

alter table public.manejos_programados
  add column if not exists validade date;

alter table public.manejos_programados
  add column if not exists carencia_dias integer;

alter table public.manejos_programados
  add column if not exists vermifugo_id uuid references public.vermifugos(id) on delete set null;

alter table public.manejos_programados
  add column if not exists vermifugo_nome text;

alter table public.manejos_programados
  add column if not exists medicamento_id uuid references public.medicamentos(id) on delete set null;

alter table public.manejos_programados
  add column if not exists medicamento_nome text;

alter table public.manejos
  add column if not exists vermifugo_id uuid references public.vermifugos(id) on delete set null;

alter table public.manejos
  add column if not exists vermifugo_nome text;

alter table public.manejos
  add column if not exists vermifugo_principio_ativo text;

alter table public.manejos
  add column if not exists medicamento_id uuid references public.medicamentos(id) on delete set null;

alter table public.manejos
  add column if not exists medicamento_nome text;

alter table public.manejos
  add column if not exists medicamento_principio_ativo text;

create index if not exists idx_vermifugos_fazenda_ativo
  on public.vermifugos(fazenda_id, ativo);

create index if not exists idx_medicamentos_fazenda_ativo
  on public.medicamentos(fazenda_id, ativo);

alter table public.vermifugos enable row level security;
alter table public.medicamentos enable row level security;

drop policy if exists "vermifugos_select_proprietario" on public.vermifugos;
create policy "vermifugos_select_proprietario" on public.vermifugos for select using (exists (select 1 from public.fazendas f where f.id = vermifugos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "vermifugos_insert_proprietario" on public.vermifugos;
create policy "vermifugos_insert_proprietario" on public.vermifugos for insert with check (exists (select 1 from public.fazendas f where f.id = vermifugos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "vermifugos_update_proprietario" on public.vermifugos;
create policy "vermifugos_update_proprietario" on public.vermifugos for update using (exists (select 1 from public.fazendas f where f.id = vermifugos.fazenda_id and f.proprietario_id = auth.uid())) with check (exists (select 1 from public.fazendas f where f.id = vermifugos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "vermifugos_delete_proprietario" on public.vermifugos;
create policy "vermifugos_delete_proprietario" on public.vermifugos for delete using (exists (select 1 from public.fazendas f where f.id = vermifugos.fazenda_id and f.proprietario_id = auth.uid()));

drop policy if exists "medicamentos_select_proprietario" on public.medicamentos;
create policy "medicamentos_select_proprietario" on public.medicamentos for select using (exists (select 1 from public.fazendas f where f.id = medicamentos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "medicamentos_insert_proprietario" on public.medicamentos;
create policy "medicamentos_insert_proprietario" on public.medicamentos for insert with check (exists (select 1 from public.fazendas f where f.id = medicamentos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "medicamentos_update_proprietario" on public.medicamentos;
create policy "medicamentos_update_proprietario" on public.medicamentos for update using (exists (select 1 from public.fazendas f where f.id = medicamentos.fazenda_id and f.proprietario_id = auth.uid())) with check (exists (select 1 from public.fazendas f where f.id = medicamentos.fazenda_id and f.proprietario_id = auth.uid()));
drop policy if exists "medicamentos_delete_proprietario" on public.medicamentos;
create policy "medicamentos_delete_proprietario" on public.medicamentos for delete using (exists (select 1 from public.fazendas f where f.id = medicamentos.fazenda_id and f.proprietario_id = auth.uid()));
