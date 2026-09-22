-- Módulos finais do Fazenda Baixinha: farmácia e financeiro.
-- Produtos pertencem à fazenda. Movimentações podem ser vinculadas ao lote/animal.

create table if not exists public.farmacia_produtos (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  nome text not null,
  categoria text not null check (categoria in ('vacina','vermifugo','medicamento','outro')),
  principio_ativo text,
  unidade text not null default 'unidade',
  estoque numeric(12,3) not null default 0 check (estoque >= 0),
  estoque_minimo numeric(12,3) not null default 0 check (estoque_minimo >= 0),
  validade date,
  ativo boolean not null default true,
  observacoes text,
  created_at timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.farmacia_movimentacoes (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  produto_id uuid not null references public.farmacia_produtos(id) on delete restrict,
  tipo text not null check (tipo in ('entrada','saida')),
  quantidade numeric(12,3) not null check (quantidade > 0),
  data date not null default current_date,
  lote_id uuid references public.rebanhos(id) on delete set null,
  animal_id uuid references public.animais(id) on delete set null,
  observacoes text,
  created_at timestamptz not null default now()
);

create table if not exists public.financeiro_lancamentos (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  tipo text not null check (tipo in ('receita','despesa')),
  categoria text not null,
  descricao text not null,
  valor numeric(14,2) not null check (valor > 0),
  data date not null default current_date,
  lote_id uuid references public.rebanhos(id) on delete set null,
  animal_id uuid references public.animais(id) on delete set null,
  observacoes text,
  created_at timestamptz not null default now()
);

create index if not exists farmacia_produtos_fazenda_idx
  on public.farmacia_produtos(fazenda_id, ativo, nome);
create index if not exists farmacia_movimentacoes_fazenda_data_idx
  on public.farmacia_movimentacoes(fazenda_id, data desc);
create index if not exists farmacia_movimentacoes_lote_idx
  on public.farmacia_movimentacoes(lote_id, data desc);
create index if not exists financeiro_lancamentos_fazenda_data_idx
  on public.financeiro_lancamentos(fazenda_id, data desc);
create index if not exists financeiro_lancamentos_lote_idx
  on public.financeiro_lancamentos(lote_id, data desc);

alter table public.farmacia_produtos enable row level security;
alter table public.farmacia_movimentacoes enable row level security;
alter table public.financeiro_lancamentos enable row level security;

drop policy if exists "farmacia_produtos_select" on public.farmacia_produtos;
create policy "farmacia_produtos_select" on public.farmacia_produtos for select to authenticated
using (exists (select 1 from public.fazendas f where f.id = farmacia_produtos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "farmacia_produtos_insert" on public.farmacia_produtos;
create policy "farmacia_produtos_insert" on public.farmacia_produtos for insert to authenticated
with check (exists (select 1 from public.fazendas f where f.id = farmacia_produtos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "farmacia_produtos_update" on public.farmacia_produtos;
create policy "farmacia_produtos_update" on public.farmacia_produtos for update to authenticated
using (exists (select 1 from public.fazendas f where f.id = farmacia_produtos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true))
with check (exists (select 1 from public.fazendas f where f.id = farmacia_produtos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "farmacia_produtos_delete" on public.farmacia_produtos;
create policy "farmacia_produtos_delete" on public.farmacia_produtos for delete to authenticated
using (exists (select 1 from public.fazendas f where f.id = farmacia_produtos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "farmacia_movimentacoes_select" on public.farmacia_movimentacoes;
create policy "farmacia_movimentacoes_select" on public.farmacia_movimentacoes for select to authenticated
using (exists (select 1 from public.fazendas f where f.id = farmacia_movimentacoes.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "farmacia_movimentacoes_insert" on public.farmacia_movimentacoes;
create policy "farmacia_movimentacoes_insert" on public.farmacia_movimentacoes for insert to authenticated
with check (
  exists (select 1 from public.fazendas f where f.id = farmacia_movimentacoes.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true)
  and exists (select 1 from public.farmacia_produtos p where p.id = farmacia_movimentacoes.produto_id and p.fazenda_id = farmacia_movimentacoes.fazenda_id)
);

drop policy if exists "farmacia_movimentacoes_delete" on public.farmacia_movimentacoes;
create policy "farmacia_movimentacoes_delete" on public.farmacia_movimentacoes for delete to authenticated
using (exists (select 1 from public.fazendas f where f.id = farmacia_movimentacoes.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "financeiro_lancamentos_select" on public.financeiro_lancamentos;
create policy "financeiro_lancamentos_select" on public.financeiro_lancamentos for select to authenticated
using (exists (select 1 from public.fazendas f where f.id = financeiro_lancamentos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "financeiro_lancamentos_insert" on public.financeiro_lancamentos;
create policy "financeiro_lancamentos_insert" on public.financeiro_lancamentos for insert to authenticated
with check (exists (select 1 from public.fazendas f where f.id = financeiro_lancamentos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "financeiro_lancamentos_update" on public.financeiro_lancamentos;
create policy "financeiro_lancamentos_update" on public.financeiro_lancamentos for update to authenticated
using (exists (select 1 from public.fazendas f where f.id = financeiro_lancamentos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true))
with check (exists (select 1 from public.fazendas f where f.id = financeiro_lancamentos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));

drop policy if exists "financeiro_lancamentos_delete" on public.financeiro_lancamentos;
create policy "financeiro_lancamentos_delete" on public.financeiro_lancamentos for delete to authenticated
using (exists (select 1 from public.fazendas f where f.id = financeiro_lancamentos.fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true));
