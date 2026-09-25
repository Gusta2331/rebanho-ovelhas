-- Proteção definitiva dos brincos:
-- um brinco usado por uma fazenda nunca pode ser reutilizado,
-- mesmo depois da exclusão do animal.

create table if not exists public.animais_brincos_historico (
  id uuid primary key default gen_random_uuid(),
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  brinco integer not null,
  primeiro_animal_id uuid,
  primeiro_uso_em timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (fazenda_id, brinco)
);

create index if not exists animais_brincos_historico_fazenda_idx
  on public.animais_brincos_historico(fazenda_id, brinco);

alter table public.animais_brincos_historico enable row level security;

drop policy if exists "animais_brincos_historico_select" on public.animais_brincos_historico;
create policy "animais_brincos_historico_select"
on public.animais_brincos_historico
for select to authenticated
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = animais_brincos_historico.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
);

-- Reserva os brincos que já existem antes desta migração.
insert into public.animais_brincos_historico (
  fazenda_id,
  brinco,
  primeiro_animal_id,
  primeiro_uso_em
)
select
  a.fazenda_id,
  a.brinco,
  min(a.id),
  min(coalesce(a.created_at, now()))
from public.animais a
where a.brinco is not null
group by a.fazenda_id, a.brinco
on conflict (fazenda_id, brinco) do nothing;

-- Mantém a própria tabela de animais protegida enquanto o registro ainda existe.
create unique index if not exists animais_fazenda_brinco_uidx
  on public.animais(fazenda_id, brinco)
  where brinco is not null;

create or replace function public.reservar_brinco_animal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.brinco is null then
    raise exception 'O brinco do animal é obrigatório.';
  end if;

  insert into public.animais_brincos_historico (
    fazenda_id,
    brinco,
    primeiro_animal_id
  )
  values (
    new.fazenda_id,
    new.brinco,
    new.id
  )
  on conflict (fazenda_id, brinco) do nothing;

  if not exists (
    select 1
    from public.animais_brincos_historico h
    where h.fazenda_id = new.fazenda_id
      and h.brinco = new.brinco
      and h.primeiro_animal_id = new.id
  ) then
    raise exception
      'O brinco % já foi utilizado nesta fazenda e não pode ser reutilizado.',
      new.brinco;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reservar_brinco_animal on public.animais;

create trigger trg_reservar_brinco_animal
after insert or update of fazenda_id, brinco
on public.animais
for each row
execute function public.reservar_brinco_animal();

-- A função é usada pelo trigger e não deve ficar disponível para chamadas
-- arbitrárias pela aplicação.
revoke all on function public.reservar_brinco_animal() from public;
