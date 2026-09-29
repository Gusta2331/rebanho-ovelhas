create table if not exists public.animal_composicoes_raciais (
  id uuid primary key default gen_random_uuid(),
  animal_id uuid not null references public.animais(id) on delete cascade,
  raca_id uuid not null references public.racas(id) on delete restrict,
  percentual numeric(6,3) not null check (percentual > 0 and percentual <= 100),
  automatico boolean not null default true,
  created_at timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint animal_composicao_raca_unica unique (animal_id, raca_id)
);
create index if not exists animal_composicoes_raciais_animal_idx on public.animal_composicoes_raciais(animal_id);
alter table public.animal_composicoes_raciais enable row level security;
drop policy if exists "animal_composicoes_select_proprietario" on public.animal_composicoes_raciais;
create policy "animal_composicoes_select_proprietario" on public.animal_composicoes_raciais for select to authenticated using (
  exists (select 1 from public.animais a join public.fazendas f on f.id=a.fazenda_id where a.id=animal_composicoes_raciais.animal_id and f.proprietario_id=auth.uid() and f.ativo=true)
);
drop policy if exists "animal_composicoes_insert_proprietario" on public.animal_composicoes_raciais;
create policy "animal_composicoes_insert_proprietario" on public.animal_composicoes_raciais for insert to authenticated with check (
  exists (select 1 from public.animais a join public.fazendas f on f.id=a.fazenda_id where a.id=animal_composicoes_raciais.animal_id and f.proprietario_id=auth.uid() and f.ativo=true)
);
drop policy if exists "animal_composicoes_update_proprietario" on public.animal_composicoes_raciais;
create policy "animal_composicoes_update_proprietario" on public.animal_composicoes_raciais for update to authenticated using (
  exists (select 1 from public.animais a join public.fazendas f on f.id=a.fazenda_id where a.id=animal_composicoes_raciais.animal_id and f.proprietario_id=auth.uid() and f.ativo=true)
) with check (
  exists (select 1 from public.animais a join public.fazendas f on f.id=a.fazenda_id where a.id=animal_composicoes_raciais.animal_id and f.proprietario_id=auth.uid() and f.ativo=true)
);
drop policy if exists "animal_composicoes_delete_proprietario" on public.animal_composicoes_raciais;
create policy "animal_composicoes_delete_proprietario" on public.animal_composicoes_raciais for delete to authenticated using (
  exists (select 1 from public.animais a join public.fazendas f on f.id=a.fazenda_id where a.id=animal_composicoes_raciais.animal_id and f.proprietario_id=auth.uid() and f.ativo=true)
);
notify pgrst, 'reload schema';
