-- Integração segura entre Manejo Sanitário e Farmácia.
-- Registros antigos continuam funcionando pelos catálogos legados.
-- Novos manejos podem apontar para um produto real da farmácia e consumir estoque.

alter table public.farmacia_produtos
  add column if not exists dose numeric(10,3);

alter table public.farmacia_produtos
  add column if not exists dose_unidade text;

alter table public.farmacia_produtos
  add column if not exists peso_referencia_kg numeric(10,2);

alter table public.farmacia_produtos
  add column if not exists via_aplicacao text;

alter table public.farmacia_produtos
  add column if not exists carencia_dias integer;

alter table public.manejos
  add column if not exists farmacia_produto_id uuid
    references public.farmacia_produtos(id) on delete set null;

alter table public.manejos
  add column if not exists farmacia_quantidade numeric(12,3);

alter table public.farmacia_movimentacoes
  add column if not exists manejo_id uuid
    references public.manejos(id) on delete set null;

create index if not exists manejos_farmacia_produto_idx
  on public.manejos(farmacia_produto_id);

create unique index if not exists farmacia_movimentacoes_manejo_uidx
  on public.farmacia_movimentacoes(manejo_id)
  where manejo_id is not null;

-- A movimentação de consumo passa a poder apontar para o manejo que a gerou.
drop policy if exists "farmacia_movimentacoes_insert" on public.farmacia_movimentacoes;
create policy "farmacia_movimentacoes_insert"
on public.farmacia_movimentacoes
for insert
to authenticated
with check (
  exists (
    select 1
    from public.fazendas f
    where f.id = farmacia_movimentacoes.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
  and exists (
    select 1
    from public.farmacia_produtos p
    where p.id = farmacia_movimentacoes.produto_id
      and p.fazenda_id = farmacia_movimentacoes.fazenda_id
  )
  and (
    farmacia_movimentacoes.manejo_id is null
    or exists (
      select 1
      from public.manejos m
      where m.id = farmacia_movimentacoes.manejo_id
        and m.fazenda_id = farmacia_movimentacoes.fazenda_id
    )
  )
);

-- Atualiza a política de produto para manter o mesmo isolamento por fazenda.
drop policy if exists "farmacia_produtos_update" on public.farmacia_produtos;
create policy "farmacia_produtos_update"
on public.farmacia_produtos
for update
to authenticated
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = farmacia_produtos.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
)
with check (
  exists (
    select 1
    from public.fazendas f
    where f.id = farmacia_produtos.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
);

create or replace function public.registrar_manejo_com_estoque(
  p_dados jsonb,
  p_quantidade numeric default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_fazenda_id uuid;
  v_animal_id uuid;
  v_produto_id uuid;
  v_manejo_id uuid;
  v_quantidade numeric(12,3);
  v_estoque numeric(12,3);
  v_data date;
  v_tipo text;
  v_observacoes text;
  v_rebanho_id uuid;
  v_existente jsonb;
begin
  v_fazenda_id := nullif(p_dados->>'fazenda_id', '')::uuid;
  v_animal_id := nullif(p_dados->>'animal_id', '')::uuid;
  v_produto_id := nullif(p_dados->>'farmacia_produto_id', '')::uuid;
  v_manejo_id := nullif(p_dados->>'id', '')::uuid;
  v_quantidade := coalesce(
    p_quantidade,
    nullif(p_dados->>'farmacia_quantidade', '')::numeric,
    nullif(p_dados->>'dose', '')::numeric
  );
  v_data := nullif(p_dados->>'data', '')::date;
  v_tipo := p_dados->>'tipo';
  v_observacoes := nullif(p_dados->>'observacoes', '');

  if v_fazenda_id is null or v_animal_id is null or v_manejo_id is null then
    raise exception 'Dados do manejo incompletos.';
  end if;

  -- Permite reprocessamento seguro de uma operação offline já concluída.
  select to_jsonb(m)
    into v_existente
  from public.manejos m
  where m.id = v_manejo_id
    and m.fazenda_id = v_fazenda_id;

  if v_existente is not null then
    return v_existente;
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

  select a.rebanho_id
    into v_rebanho_id
  from public.animais a
  where a.id = v_animal_id
    and a.fazenda_id = v_fazenda_id
    and a.status = 'ativo';

  if not found then
    raise exception 'O animal selecionado não está ativo ou não pertence à fazenda.';
  end if;

  if v_produto_id is not null then
    if v_quantidade is null or v_quantidade <= 0 then
      raise exception 'Informe uma quantidade válida para o consumo da farmácia.';
    end if;

    update public.farmacia_produtos
       set estoque = estoque - v_quantidade,
           atualizado_em = now()
     where id = v_produto_id
       and fazenda_id = v_fazenda_id
       and ativo = true
       and estoque >= v_quantidade
     returning estoque into v_estoque;

    if not found then
      raise exception 'Estoque insuficiente ou produto não encontrado.';
    end if;
  end if;

  insert into public.manejos (
    id,
    fazenda_id,
    animal_id,
    tipo,
    data,
    famacha_escore,
    observacoes,
    vacina_id,
    vacina_nome,
    vacina_fabricante,
    vacina_lote,
    outro_nome,
    peso_kg,
    dose,
    dose_unidade,
    peso_referencia_kg,
    via_aplicacao,
    validade,
    carencia_dias,
    vermifugo_id,
    vermifugo_nome,
    vermifugo_principio_ativo,
    medicamento_id,
    medicamento_nome,
    medicamento_principio_ativo,
    enfermidade,
    farmacia_produto_id,
    farmacia_quantidade
  )
  values (
    v_manejo_id,
    v_fazenda_id,
    v_animal_id,
    v_tipo,
    v_data,
    nullif(p_dados->>'famacha_escore', '')::integer,
    v_observacoes,
    nullif(p_dados->>'vacina_id', '')::uuid,
    nullif(p_dados->>'vacina_nome', ''),
    nullif(p_dados->>'vacina_fabricante', ''),
    nullif(p_dados->>'vacina_lote', ''),
    nullif(p_dados->>'outro_nome', ''),
    nullif(p_dados->>'peso_kg', '')::numeric,
    nullif(p_dados->>'dose', '')::numeric,
    nullif(p_dados->>'dose_unidade', ''),
    nullif(p_dados->>'peso_referencia_kg', '')::numeric,
    nullif(p_dados->>'via_aplicacao', ''),
    nullif(p_dados->>'validade', '')::date,
    nullif(p_dados->>'carencia_dias', '')::integer,
    nullif(p_dados->>'vermifugo_id', '')::uuid,
    nullif(p_dados->>'vermifugo_nome', ''),
    nullif(p_dados->>'vermifugo_principio_ativo', ''),
    nullif(p_dados->>'medicamento_id', '')::uuid,
    nullif(p_dados->>'medicamento_nome', ''),
    nullif(p_dados->>'medicamento_principio_ativo', ''),
    nullif(p_dados->>'enfermidade', ''),
    v_produto_id,
    v_quantidade
  );

  if v_produto_id is not null then
    insert into public.farmacia_movimentacoes (
      id,
      fazenda_id,
      produto_id,
      tipo,
      quantidade,
      data,
      lote_id,
      animal_id,
      manejo_id,
      observacoes
    )
    values (
      gen_random_uuid(),
      v_fazenda_id,
      v_produto_id,
      'saida',
      v_quantidade,
      v_data,
      v_rebanho_id,
      v_animal_id,
      v_manejo_id,
      coalesce(v_observacoes, 'Consumo registrado pelo manejo sanitário.')
    );
  end if;

  select to_jsonb(m)
    into v_existente
  from public.manejos m
  where m.id = v_manejo_id;

  return v_existente;
end;
$$;

create or replace function public.registrar_manejos_com_estoque(
  p_itens jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_item jsonb;
  v_resultados jsonb := '[]'::jsonb;
  v_resultado jsonb;
begin
  if jsonb_typeof(p_itens) <> 'array' then
    raise exception 'Os itens do manejo em lote devem ser uma lista.';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_itens)
  loop
    v_resultado := public.registrar_manejo_com_estoque(v_item, null);
    v_resultados := v_resultados || jsonb_build_array(v_resultado);
  end loop;

  return v_resultados;
end;
$$;

create or replace function public.atualizar_manejo_com_estoque(
  p_id uuid,
  p_fazenda_id uuid,
  p_dados jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_antigo public.manejos%rowtype;
  v_mov public.farmacia_movimentacoes%rowtype;
  v_novo_produto uuid;
  v_nova_qtd numeric(12,3);
  v_delta numeric(12,3);
  v_rebanho_id uuid;
  v_resultado jsonb;
begin
  select *
    into v_antigo
  from public.manejos
  where id = p_id
    and fazenda_id = p_fazenda_id
  for update;

  if not found then
    raise exception 'Manejo não encontrado.';
  end if;

  v_novo_produto := nullif(p_dados->>'farmacia_produto_id', '')::uuid;
  v_nova_qtd := nullif(
    coalesce(p_dados->>'farmacia_quantidade', p_dados->>'dose'),
    ''
  )::numeric;

  if v_novo_produto is not null and (v_nova_qtd is null or v_nova_qtd <= 0) then
    raise exception 'Informe uma quantidade válida para o consumo da farmácia.';
  end if;

  select *
    into v_mov
  from public.farmacia_movimentacoes
  where manejo_id = p_id
  for update;

  if found then
    if v_novo_produto = v_mov.produto_id then
      v_delta := coalesce(v_nova_qtd, 0) - v_mov.quantidade;

      if v_delta > 0 then
        update public.farmacia_produtos
           set estoque = estoque - v_delta,
               atualizado_em = now()
         where id = v_mov.produto_id
           and fazenda_id = p_fazenda_id
           and ativo = true
           and estoque >= v_delta;

        if not found then
          raise exception 'Estoque insuficiente para atualizar o manejo.';
        end if;
      elsif v_delta < 0 then
        update public.farmacia_produtos
           set estoque = estoque + abs(v_delta),
               atualizado_em = now()
         where id = v_mov.produto_id
           and fazenda_id = p_fazenda_id;
      end if;

      update public.farmacia_movimentacoes
         set quantidade = v_nova_qtd,
             data = nullif(p_dados->>'data', '')::date,
             observacoes = nullif(p_dados->>'observacoes', '')
       where id = v_mov.id;
    else
      update public.farmacia_produtos
         set estoque = estoque + v_mov.quantidade,
             atualizado_em = now()
       where id = v_mov.produto_id
         and fazenda_id = p_fazenda_id;

      if v_novo_produto is not null then
        update public.farmacia_produtos
           set estoque = estoque - v_nova_qtd,
               atualizado_em = now()
         where id = v_novo_produto
           and fazenda_id = p_fazenda_id
           and ativo = true
           and estoque >= v_nova_qtd;

        if not found then
          raise exception 'Estoque insuficiente para trocar o produto do manejo.';
        end if;
      end if;

      if v_novo_produto is null then
        delete from public.farmacia_movimentacoes where id = v_mov.id;
      else
        select a.rebanho_id
          into v_rebanho_id
        from public.animais a
        where a.id = coalesce(nullif(p_dados->>'animal_id', '')::uuid, v_antigo.animal_id)
          and a.fazenda_id = p_fazenda_id;

        update public.farmacia_movimentacoes
           set produto_id = v_novo_produto,
               quantidade = v_nova_qtd,
               data = nullif(p_dados->>'data', '')::date,
               animal_id = coalesce(nullif(p_dados->>'animal_id', '')::uuid, v_antigo.animal_id),
               lote_id = v_rebanho_id,
               observacoes = nullif(p_dados->>'observacoes', '')
         where id = v_mov.id;
      end if;
    end if;
  elsif v_novo_produto is not null then
    update public.farmacia_produtos
       set estoque = estoque - v_nova_qtd,
           atualizado_em = now()
     where id = v_novo_produto
       and fazenda_id = p_fazenda_id
       and ativo = true
       and estoque >= v_nova_qtd;

    if not found then
      raise exception 'Estoque insuficiente ou produto não encontrado.';
    end if;

    select a.rebanho_id
      into v_rebanho_id
    from public.animais a
    where a.id = coalesce(nullif(p_dados->>'animal_id', '')::uuid, v_antigo.animal_id)
      and a.fazenda_id = p_fazenda_id;

    insert into public.farmacia_movimentacoes (
      id, fazenda_id, produto_id, tipo, quantidade, data,
      lote_id, animal_id, manejo_id, observacoes
    )
    values (
      gen_random_uuid(),
      p_fazenda_id,
      v_novo_produto,
      'saida',
      v_nova_qtd,
      nullif(p_dados->>'data', '')::date,
      v_rebanho_id,
      coalesce(nullif(p_dados->>'animal_id', '')::uuid, v_antigo.animal_id),
      p_id,
      nullif(p_dados->>'observacoes', '')
    );
  end if;

  update public.manejos
     set animal_id = coalesce(nullif(p_dados->>'animal_id', '')::uuid, animal_id),
         tipo = coalesce(p_dados->>'tipo', tipo),
         data = coalesce(nullif(p_dados->>'data', '')::date, data),
         famacha_escore = nullif(p_dados->>'famacha_escore', '')::integer,
         observacoes = nullif(p_dados->>'observacoes', ''),
         vacina_id = nullif(p_dados->>'vacina_id', '')::uuid,
         vacina_nome = nullif(p_dados->>'vacina_nome', ''),
         vacina_fabricante = nullif(p_dados->>'vacina_fabricante', ''),
         vacina_lote = nullif(p_dados->>'vacina_lote', ''),
         outro_nome = nullif(p_dados->>'outro_nome', ''),
         peso_kg = nullif(p_dados->>'peso_kg', '')::numeric,
         dose = nullif(p_dados->>'dose', '')::numeric,
         dose_unidade = nullif(p_dados->>'dose_unidade', ''),
         peso_referencia_kg = nullif(p_dados->>'peso_referencia_kg', '')::numeric,
         via_aplicacao = nullif(p_dados->>'via_aplicacao', ''),
         validade = nullif(p_dados->>'validade', '')::date,
         carencia_dias = nullif(p_dados->>'carencia_dias', '')::integer,
         vermifugo_id = nullif(p_dados->>'vermifugo_id', '')::uuid,
         vermifugo_nome = nullif(p_dados->>'vermifugo_nome', ''),
         vermifugo_principio_ativo = nullif(p_dados->>'vermifugo_principio_ativo', ''),
         medicamento_id = nullif(p_dados->>'medicamento_id', '')::uuid,
         medicamento_nome = nullif(p_dados->>'medicamento_nome', ''),
         medicamento_principio_ativo = nullif(p_dados->>'medicamento_principio_ativo', ''),
         enfermidade = nullif(p_dados->>'enfermidade', ''),
         farmacia_produto_id = v_novo_produto,
         farmacia_quantidade = v_nova_qtd
   where id = p_id
     and fazenda_id = p_fazenda_id;

  select to_jsonb(m)
    into v_resultado
  from public.manejos m
  where m.id = p_id;

  return v_resultado;
end;
$$;

create or replace function public.excluir_manejo_com_estoque(
  p_id uuid,
  p_fazenda_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_mov public.farmacia_movimentacoes%rowtype;
begin
  select *
    into v_mov
  from public.farmacia_movimentacoes
  where manejo_id = p_id
    and fazenda_id = p_fazenda_id
  for update;

  if found then
    update public.farmacia_produtos
       set estoque = estoque + v_mov.quantidade,
           atualizado_em = now()
     where id = v_mov.produto_id
       and fazenda_id = p_fazenda_id;

    delete from public.farmacia_movimentacoes
    where id = v_mov.id;
  end if;

  delete from public.manejos
  where id = p_id
    and fazenda_id = p_fazenda_id;
end;
$$;

grant execute on function public.registrar_manejo_com_estoque(jsonb, numeric) to authenticated;
grant execute on function public.registrar_manejos_com_estoque(jsonb) to authenticated;
grant execute on function public.atualizar_manejo_com_estoque(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_manejo_com_estoque(uuid, uuid) to authenticated;
