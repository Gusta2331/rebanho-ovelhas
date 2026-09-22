-- Origem e custo de aquisição dos animais.
-- Compras de animais geram um lançamento financeiro automático vinculado ao animal.

alter table public.animais
  add column if not exists origem text not null default 'nascido'
    check (origem in ('nascido', 'comprado'));

alter table public.animais
  add column if not exists data_aquisicao date;

alter table public.animais
  add column if not exists valor_aquisicao numeric(14,2)
    check (valor_aquisicao is null or valor_aquisicao > 0);

alter table public.animais
  add column if not exists vendedor text;

alter table public.financeiro_lancamentos
  add column if not exists origem_automatica boolean not null default false;

create index if not exists animais_origem_idx
  on public.animais(fazenda_id, origem);

create index if not exists financeiro_lancamentos_animal_idx
  on public.financeiro_lancamentos(animal_id, data desc);

create unique index if not exists financeiro_compra_animal_unica_idx
  on public.financeiro_lancamentos(animal_id, categoria)
  where origem_automatica = true
    and tipo = 'despesa'
    and categoria = 'Compra de animal'
    and animal_id is not null;
