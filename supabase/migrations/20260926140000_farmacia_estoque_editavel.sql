-- Permite corrigir manualmente o saldo da farmácia sem quebrar lotes/FEFO.
-- A correção vira uma movimentação de entrada/saída, preservando o histórico.
create or replace function public.corrigir_estoque_farmacia(
  p_produto_id uuid,
  p_novo_estoque numeric,
  p_observacoes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_produto public.farmacia_produtos%rowtype;
  v_atual numeric(12,3);
  v_diferenca numeric(12,3);
  v_data date := current_date;
  v_lote public.farmacia_lotes%rowtype;
  v_mov_id uuid := gen_random_uuid();
  v_grupo_id uuid := gen_random_uuid();
  v_novo_total numeric(12,3);
begin
  if p_novo_estoque is null or p_novo_estoque < 0 then
    raise exception 'O estoque não pode ser negativo.';
  end if;

  select * into v_produto
  from public.farmacia_produtos p
  where p.id = p_produto_id
    and p.ativo = true
  for update;

  if not found then
    raise exception 'Produto não encontrado ou inativo.';
  end if;

  if not exists (
    select 1
    from public.fazendas f
    where f.id = v_produto.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  select coalesce(sum(l.quantidade_atual), 0)
    into v_atual
  from public.farmacia_lotes l
  where l.produto_id = p_produto_id
    and l.fazenda_id = v_produto.fazenda_id;

  v_diferenca := p_novo_estoque - v_atual;

  if v_diferenca > 0 then
    insert into public.farmacia_lotes (
      fazenda_id,
      produto_id,
      codigo_lote,
      quantidade_inicial,
      quantidade_atual,
      validade,
      fabricante,
      observacoes
    ) values (
      v_produto.fazenda_id,
      p_produto_id,
      'AJUSTE-MANUAL',
      v_diferenca,
      v_diferenca,
      null,
      v_produto.fabricante,
      coalesce(
        nullif(trim(p_observacoes), ''),
        'Ajuste manual de estoque.'
      )
    );

    insert into public.farmacia_movimentacoes (
      id,
      fazenda_id,
      produto_id,
      tipo,
      quantidade,
      data,
      observacoes,
      farmacia_lote_id,
      movimentacao_grupo_id
    ) values (
      v_mov_id,
      v_produto.fazenda_id,
      p_produto_id,
      'entrada',
      v_diferenca,
      v_data,
      coalesce(
        nullif(trim(p_observacoes), ''),
        'Ajuste manual de estoque.'
      ),
      (
        select l.id
        from public.farmacia_lotes l
        where l.produto_id = p_produto_id
          and l.fazenda_id = v_produto.fazenda_id
          and l.codigo_lote = 'AJUSTE-MANUAL'
        order by l.created_at desc
        limit 1
      ),
      v_grupo_id
    );

  elsif v_diferenca < 0 then
    v_diferenca := abs(v_diferenca);

    for v_lote in
      select *
      from public.farmacia_lotes
      where produto_id = p_produto_id
        and fazenda_id = v_produto.fazenda_id
        and quantidade_atual > 0
      order by
        case when validade is null then 1 else 0 end,
        validade asc,
        created_at asc,
        id asc
      for update
    loop
      exit when v_diferenca <= 0;

      declare
        v_consumir numeric(12,3);
      begin
        v_consumir := least(v_lote.quantidade_atual, v_diferenca);

        update public.farmacia_lotes
           set quantidade_atual = quantidade_atual - v_consumir,
               atualizado_em = now()
         where id = v_lote.id;

        insert into public.farmacia_movimentacoes (
          id,
          fazenda_id,
          produto_id,
          tipo,
          quantidade,
          data,
          observacoes,
          farmacia_lote_id,
          movimentacao_grupo_id
        ) values (
          case
            when v_diferenca = abs(p_novo_estoque - v_atual)
              then v_mov_id
            else gen_random_uuid()
          end,
          v_produto.fazenda_id,
          p_produto_id,
          'saida',
          v_consumir,
          v_data,
          coalesce(
            nullif(trim(p_observacoes), ''),
            'Ajuste manual de estoque.'
          ),
          v_lote.id,
          v_grupo_id
        );

        v_diferenca := v_diferenca - v_consumir;
      end;
    end loop;

    if v_diferenca > 0 then
      raise exception 'Não foi possível corrigir o estoque: saldo dos lotes insuficiente.';
    end if;
  end if;

  select coalesce(sum(l.quantidade_atual), 0)
    into v_novo_total
  from public.farmacia_lotes l
  where l.produto_id = p_produto_id
    and l.fazenda_id = v_produto.fazenda_id;

  update public.farmacia_produtos
     set estoque = v_novo_total,
         atualizado_em = now()
   where id = p_produto_id
     and fazenda_id = v_produto.fazenda_id;

  return jsonb_build_object(
    'produto_id', p_produto_id,
    'estoque_anterior', v_atual,
    'estoque_novo', v_novo_total
  );
end;
$$;

create or replace function public.desativar_produto_farmacia(
  p_produto_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  select p.fazenda_id
    into v_fazenda_id
  from public.farmacia_produtos p
  where p.id = p_produto_id
    and p.ativo = true;

  if v_fazenda_id is null then
    raise exception 'Produto não encontrado ou já desativado.';
  end if;

  if not exists (
    select 1
    from public.fazendas f
    where f.id = v_fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  update public.farmacia_produtos
     set ativo = false,
         atualizado_em = now()
   where id = p_produto_id
     and fazenda_id = v_fazenda_id;
end;
$$;

grant execute on function public.corrigir_estoque_farmacia(uuid, numeric, text)
  to authenticated;

grant execute on function public.desativar_produto_farmacia(uuid)
  to authenticated;


-- Permite limpar somente o historico de um produto, sem apagar o cadastro.
create or replace function public.apagar_historico_produto_farmacia(
  p_produto_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  select p.fazenda_id
    into v_fazenda_id
  from public.farmacia_produtos p
  where p.id = p_produto_id;

  if v_fazenda_id is null then
    raise exception 'Produto não encontrado.';
  end if;

  if not exists (
    select 1
    from public.fazendas f
    where f.id = v_fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  delete from public.farmacia_alertas
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  delete from public.farmacia_movimentacoes
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  delete from public.farmacia_lotes
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  update public.farmacia_produtos
     set estoque = 0,
         atualizado_em = now()
   where id = p_produto_id
     and fazenda_id = v_fazenda_id;
end;
$$;

-- Limpa todo o historico da farmacia da fazenda, mantendo os produtos cadastrados.
create or replace function public.apagar_historico_farmacia()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  select f.id
    into v_fazenda_id
  from public.fazendas f
  where f.proprietario_id = auth.uid()
    and f.ativo = true
  order by f.created_at
  limit 1;

  if v_fazenda_id is null then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  delete from public.farmacia_alertas
   where fazenda_id = v_fazenda_id;

  delete from public.farmacia_movimentacoes
   where fazenda_id = v_fazenda_id;

  delete from public.farmacia_lotes
   where fazenda_id = v_fazenda_id;

  update public.farmacia_produtos
     set estoque = 0,
         atualizado_em = now()
   where fazenda_id = v_fazenda_id;
end;
$$;

grant execute on function public.apagar_historico_produto_farmacia(uuid)
  to authenticated;

grant execute on function public.apagar_historico_farmacia()
  to authenticated;
