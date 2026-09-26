-- Corrige a gravação de movimentações internas da farmácia durante o manejo.
-- A função continua validando explicitamente a fazenda e o produto pelo auth.uid().
-- SECURITY DEFINER é necessário porque a operação interna precisa atravessar
-- a RLS de farmacia_movimentacoes/farmacia_lotes/farmacia_produtos.

create or replace function public.farmacia_consumir_fefo(
  p_fazenda_id uuid, p_produto_id uuid, p_quantidade numeric, p_data date,
  p_lote_id uuid default null, p_animal_id uuid default null,
  p_manejo_id uuid default null, p_movimentacao_grupo_id uuid default null,
  p_observacoes text default null, p_movimentacao_id uuid default null
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_restante numeric(12,3) := p_quantidade;
  v_consumir numeric(12,3);
  v_lote public.farmacia_lotes%rowtype;
  v_estoque numeric(12,3);
begin
  if p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Informe uma quantidade maior que zero.';
  end if;

  if not exists (
    select 1 from public.fazendas f
    where f.id = p_fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if not exists (
    select 1 from public.farmacia_produtos p
    where p.id = p_produto_id
      and p.fazenda_id = p_fazenda_id
      and p.ativo = true
  ) then
    raise exception 'Produto não encontrado.';
  end if;

  if p_lote_id is not null then
    select * into v_lote
    from public.farmacia_lotes
    where id = p_lote_id
      and produto_id = p_produto_id
      and fazenda_id = p_fazenda_id
      and quantidade_atual >= p_quantidade
    for update;

    if not found then
      raise exception 'Lote selecionado não possui estoque suficiente.';
    end if;

    update public.farmacia_lotes
       set quantidade_atual = quantidade_atual - p_quantidade,
           atualizado_em = now()
     where id = v_lote.id;

    insert into public.farmacia_movimentacoes (
      id, fazenda_id, produto_id, tipo, quantidade, data, lote_id, animal_id,
      manejo_id, observacoes, farmacia_lote_id, movimentacao_grupo_id
    ) values (
      coalesce(p_movimentacao_id, gen_random_uuid()),
      p_fazenda_id,
      p_produto_id,
      'saida',
      p_quantidade,
      p_data,
      (select rebanho_id from public.animais where id = p_animal_id),
      p_animal_id,
      p_manejo_id,
      p_observacoes,
      p_lote_id,
      p_movimentacao_grupo_id
    );

    v_restante := 0;
  else
    for v_lote in
      select * from public.farmacia_lotes
      where produto_id = p_produto_id
        and fazenda_id = p_fazenda_id
        and quantidade_atual > 0
      order by
        case when validade is null then 1 else 0 end,
        validade asc,
        created_at asc,
        id asc
      for update
    loop
      exit when v_restante <= 0;

      v_consumir := least(v_lote.quantidade_atual, v_restante);

      update public.farmacia_lotes
         set quantidade_atual = quantidade_atual - v_consumir,
             atualizado_em = now()
       where id = v_lote.id;

      insert into public.farmacia_movimentacoes (
        id, fazenda_id, produto_id, tipo, quantidade, data, lote_id, animal_id,
        manejo_id, observacoes, farmacia_lote_id, movimentacao_grupo_id
      ) values (
        case
          when p_movimentacao_id is not null
            and v_restante = p_quantidade
          then p_movimentacao_id
          else gen_random_uuid()
        end,
        p_fazenda_id,
        p_produto_id,
        'saida',
        v_consumir,
        p_data,
        (select rebanho_id from public.animais where id = p_animal_id),
        p_animal_id,
        p_manejo_id,
        p_observacoes,
        v_lote.id,
        p_movimentacao_grupo_id
      );

      v_restante := v_restante - v_consumir;
    end loop;
  end if;

  if v_restante > 0 then
    raise exception 'Estoque insuficiente.';
  end if;

  select coalesce(sum(quantidade_atual), 0)
    into v_estoque
  from public.farmacia_lotes
  where produto_id = p_produto_id
    and fazenda_id = p_fazenda_id;

  update public.farmacia_produtos
     set estoque = v_estoque,
         atualizado_em = now()
   where id = p_produto_id
     and fazenda_id = p_fazenda_id;

  return p_quantidade;
end;
$$;

grant execute on function public.farmacia_consumir_fefo(
  uuid, uuid, numeric, date, uuid, uuid, uuid, uuid, text, uuid
) to authenticated;
