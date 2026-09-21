create table if not exists public.manejos_programados (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  tipo text not null check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','outro')),
  data_programada date not null,
  observacoes text,
  concluido boolean not null default false,
  realizado_em date,
  created_at timestamptz not null default now()
);
create table if not exists public.manejos_programados_animais (
  id uuid primary key,
  manejo_programado_id uuid not null references public.manejos_programados(id) on delete cascade,
  animal_id uuid not null references public.animais(id) on delete restrict,
  unique (manejo_programado_id, animal_id)
);
create index if not exists idx_manejos_programados_fazenda_data on public.manejos_programados(fazenda_id, data_programada);
create index if not exists idx_manejos_programados_animais_manejo on public.manejos_programados_animais(manejo_programado_id);
create index if not exists idx_manejos_programados_animais_animal on public.manejos_programados_animais(animal_id);
alter table public.manejos_programados enable row level security;
alter table public.manejos_programados_animais enable row level security;
create policy "manejos_programados_select" on public.manejos_programados for select using (fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid()));
create policy "manejos_programados_insert" on public.manejos_programados for insert with check (fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid()));
create policy "manejos_programados_update" on public.manejos_programados for update using (fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid())) with check (fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid()));
create policy "manejos_programados_delete" on public.manejos_programados for delete using (fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid()));
create policy "manejos_programados_animais_select" on public.manejos_programados_animais for select using (manejo_programado_id in (select id from public.manejos_programados where fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid())));
create policy "manejos_programados_animais_insert" on public.manejos_programados_animais for insert with check (manejo_programado_id in (select id from public.manejos_programados where fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid())));
create policy "manejos_programados_animais_delete" on public.manejos_programados_animais for delete using (manejo_programado_id in (select id from public.manejos_programados where fazenda_id in (select id from public.fazendas where proprietario_id = auth.uid())));
