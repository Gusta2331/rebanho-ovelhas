create table if not exists public.manejos (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  animal_id uuid not null references public.animais(id) on delete restrict,
  tipo text not null check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','outro')),
  data date not null,
  famacha_escore integer check (famacha_escore is null or famacha_escore between 1 and 5),
  observacoes text,
  created_at timestamptz not null default now(),
  constraint manejo_famacha_consistente check (
    (tipo = 'famacha' and famacha_escore is not null) or
    (tipo <> 'famacha' and famacha_escore is null)
  )
);

create index if not exists manejos_fazenda_id_idx on public.manejos(fazenda_id);
create index if not exists manejos_animal_id_idx on public.manejos(animal_id);
create index if not exists manejos_data_idx on public.manejos(data desc);

alter table public.manejos enable row level security;

drop policy if exists "manejos_select_proprietario" on public.manejos;
create policy "manejos_select_proprietario" on public.manejos for select to authenticated
using (exists (select 1 from public.fazendas f where f.id = manejos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "manejos_insert_proprietario" on public.manejos;
create policy "manejos_insert_proprietario" on public.manejos for insert to authenticated
with check (
  exists (select 1 from public.fazendas f where f.id = manejos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true)
  and exists (select 1 from public.animais a where a.id = manejos.animal_id and a.fazenda_id = manejos.fazenda_id and a.status = 'ativo')
);

drop policy if exists "manejos_update_proprietario" on public.manejos;
create policy "manejos_update_proprietario" on public.manejos for update to authenticated
using (exists (select 1 from public.fazendas f where f.id = manejos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true))
with check (exists (select 1 from public.fazendas f where f.id = manejos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "manejos_delete_proprietario" on public.manejos;
create policy "manejos_delete_proprietario" on public.manejos for delete to authenticated
using (exists (select 1 from public.fazendas f where f.id = manejos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));
