-- Venda de animal com histórico detalhado e receita financeira automática.
-- A operação de venda é concluída por RPC para manter status, venda e financeiro atômicos.

create table if not exists public.vendas_animais (
  id uuid primary key,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  animal_id uuid not null unique references public.animais(id) on delete restrict,
  lote_id uuid not null references public.rebanhos(id) on delete restrict,
  data_venda date not null default current_date,
  tipo_venda text not null check (tipo_venda in ('valor_fechado', 'por_kg')),
  peso_kg numeric(10,2),
  preco_por_kg numeric(10,2),
  valor_total numeric(14,2) not null check (valor_total > 0),
  comprador text,
  observacoes text,
  created_at timestamptz not null default now(),
  constraint venda_valor_fechado_consistente check (
    (tipo_venda = 'valor_fechado' and peso_kg is null and preco_por_kg is null)
    or
    (tipo_venda = 'por_kg' and peso_kg is not null and peso_kg > 0 and preco_por_kg is not null and preco_por_kg > 0)
  ),
  constraint venda_total_por_kg_consistente check (
    tipo_venda = 'valor_fechado'
    or round(valor_total, 2) = round(peso_kg * preco_por_kg, 2)
  )
);

create index if not exists vendas_animais_fazenda_data_idx
  on public.vendas_animais(fazenda_id, data_venda desc);

create index if not exists vendas_animais_lote_data_idx
  on public.vendas_animais(lote_id, data_venda desc);

create index if not exists vendas_animais_animal_idx
  on public.vendas_animais(animal_id);

alter table public.vendas_animais enable row level security;

drop policy if exists "vendas_animais_select" on public.vendas_animais;
create policy "vendas_animais_select" on public.vendas_animais for select to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = vendas_animais.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "vendas_animais_insert" on public.vendas_animais;
create policy "vendas_animais_insert" on public.vendas_animais for insert to authenticated
with check (exists (
  select 1 from public.fazendas f
  where f.id = vendas_animais.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "vendas_animais_update" on public.vendas_animais;
create policy "vendas_animais_update" on public.vendas_animais for update to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = vendas_animais.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
))
with check (exists (
  select 1 from public.fazendas f
  where f.id = vendas_animais.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "vendas_animais_delete" on public.vendas_animais;
create policy "vendas_animais_delete" on public.vendas_animais for delete to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = vendas_animais.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

create unique index if not exists financeiro_venda_animal_unica_idx
  on public.financeiro_lancamentos(animal_id, categoria)
  where origem_automatica = true
    and tipo = 'receita'
    and categoria = 'Venda de animal'
    and animal_id is not null;

create or replace function public.vender_animal(
  p_animal_id uuid,
  p_lote_id uuid,
  p_data_venda date,
  p_tipo_venda text,
  p_peso_kg numeric,
  p_preco_por_kg numeric,
  p_valor_total numeric,
  p_comprador text,
  p_observacoes text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
  v_animal record;
  v_venda_id uuid;
  v_valor_calculado numeric(14,2);
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select f.id into v_fazenda_id
    from public.fazendas f
   where f.proprietario_id = auth.uid()
     and f.ativo = true
   limit 1;

  if v_fazenda_id is null then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  if not exists (
    select 1 from public.rebanhos r
     where r.id = p_lote_id
       and r.fazenda_id = v_fazenda_id
       and r.ativo = true
  ) then
    raise exception 'O lote selecionado não pertence à fazenda atual ou está inativo.';
  end if;

  select a.id, a.brinco, a.nome, a.rebanho_id, a.status
    into v_animal
    from public.animais a
   where a.id = p_animal_id
     and a.fazenda_id = v_fazenda_id
   for update;

  if v_animal.id is null then
    raise exception 'Animal não encontrado na fazenda atual.';
  end if;

  if v_animal.status <> 'ativo' then
    raise exception 'Somente animais ativos podem ser vendidos.';
  end if;

  if v_animal.rebanho_id <> p_lote_id then
    raise exception 'O animal não pertence ao lote selecionado.';
  end if;

  if exists (select 1 from public.vendas_animais v where v.animal_id = p_animal_id) then
    raise exception 'Este animal já possui uma venda registrada.';
  end if;

  if p_data_venda is null then
    raise exception 'Informe a data da venda.';
  end if;

  if p_data_venda > current_date then
    raise exception 'A data da venda não pode ser futura.';
  end if;

  if p_tipo_venda not in ('valor_fechado', 'por_kg') then
    raise exception 'Tipo de venda inválido.';
  end if;

  if p_valor_total is null or p_valor_total <= 0 then
    raise exception 'O valor total da venda deve ser maior que zero.';
  end if;

  if p_tipo_venda = 'valor_fechado' then
    if p_peso_kg is not null or p_preco_por_kg is not null then
      raise exception 'Uma venda por valor fechado não deve informar peso ou preço por kg.';
    end if;
  else
    if p_peso_kg is null or p_peso_kg <= 0 then
      raise exception 'Informe um peso de venda maior que zero.';
    end if;

    if p_preco_por_kg is null or p_preco_por_kg <= 0 then
      raise exception 'Informe um preço por kg maior que zero.';
    end if;

    v_valor_calculado := round(p_peso_kg * p_preco_por_kg, 2);

    if v_valor_calculado <> round(p_valor_total, 2) then
      raise exception 'O valor total não corresponde ao peso multiplicado pelo preço por kg.';
    end if;
  end if;

  v_venda_id := gen_random_uuid();

  insert into public.vendas_animais (
    id, fazenda_id, animal_id, lote_id, data_venda, tipo_venda,
    peso_kg, preco_por_kg, valor_total, comprador, observacoes
  ) values (
    v_venda_id, v_fazenda_id, p_animal_id, p_lote_id, p_data_venda,
    p_tipo_venda, p_peso_kg, p_preco_por_kg, round(p_valor_total, 2),
    nullif(trim(p_comprador), ''), nullif(trim(p_observacoes), '')
  );

  update public.animais
     set status = 'vendido',
         data_saida = p_data_venda::timestamptz,
         atualizado_em = now()
   where id = p_animal_id
     and fazenda_id = v_fazenda_id;

  insert into public.financeiro_lancamentos (
    id, fazenda_id, tipo, categoria, descricao, valor, data,
    lote_id, animal_id, observacoes, origem_automatica
  ) values (
    gen_random_uuid(),
    v_fazenda_id,
    'receita',
    'Venda de animal',
    'Venda do animal brinco ' || lpad(v_animal.brinco::text, 3, '0'),
    round(p_valor_total, 2),
    p_data_venda,
    p_lote_id,
    p_animal_id,
    nullif(trim(concat_ws(' • ',
      case
        when p_tipo_venda = 'por_kg'
        then 'Venda por kg: ' || to_char(p_peso_kg, 'FM999999990.00') || ' kg × R$ ' || to_char(p_preco_por_kg, 'FM999999990.00')
        else 'Venda por valor fechado'
      end,
      case when nullif(trim(p_comprador), '') is not null then 'Comprador: ' || trim(p_comprador) end,
      case when nullif(trim(p_observacoes), '') is not null then trim(p_observacoes) end
    )), ''),
    true
  );

  return v_venda_id;
end;
$$;

grant execute on function public.vender_animal(
  uuid, uuid, date, text, numeric, numeric, numeric, text, text
) to authenticated;
