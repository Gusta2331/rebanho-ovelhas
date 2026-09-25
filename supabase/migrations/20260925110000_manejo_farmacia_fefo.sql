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
  v_fazenda_id uuid := nullif(p_dados->>'fazenda_id', '')::uuid;
  v_animal_id uuid := nullif(p_dados->>'animal_id', '')::uuid;
  v_produto_id uuid := nullif(p_dados->>'farmacia_produto_id', '')::uuid;
  v_manejo_id uuid := nullif(p_dados->>'id', '')::uuid;
  v_quantidade numeric(12,3) := coalesce(p_quantidade, nullif(p_dados->>'farmacia_quantidade', '')::numeric, nullif(p_dados->>'dose', '')::numeric);
  v_data date := nullif(p_dados->>'data', '')::date;
  v_observacoes text := nullif(p_dados->>'observacoes', '');
  v_existente jsonb;
begin
  select to_jsonb(m) into v_existente from public.manejos m
  where m.id = v_manejo_id and m.fazenda_id = v_fazenda_id;
  if v_existente is not null then return v_existente; end if;

  if not exists (select 1 from public.fazendas f where f.id = v_fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if not exists (select 1 from public.animais a where a.id = v_animal_id and a.fazenda_id = v_fazenda_id and a.status = 'ativo') then
    raise exception 'O animal selecionado não está ativo ou não pertence à fazenda.';
  end if;

  if v_produto_id is not null then
    perform public.farmacia_consumir_fefo(
      v_fazenda_id, v_produto_id, v_quantidade, v_data,
      null, v_animal_id, v_manejo_id, gen_random_uuid(),
      coalesce(v_observacoes, 'Consumo registrado pelo manejo sanitário.'),
      null
    );
  end if;

  insert into public.manejos (
    id, fazenda_id, animal_id, tipo, data, famacha_escore, observacoes,
    vacina_id, vacina_nome, vacina_fabricante, vacina_lote, outro_nome,
    peso_kg, dose, dose_unidade, peso_referencia_kg, via_aplicacao, validade,
    carencia_dias, vermifugo_id, vermifugo_nome, vermifugo_principio_ativo,
    medicamento_id, medicamento_nome, medicamento_principio_ativo, enfermidade,
    farmacia_produto_id, farmacia_quantidade
  ) values (
    v_manejo_id, v_fazenda_id, v_animal_id, p_dados->>'tipo', v_data,
    nullif(p_dados->>'famacha_escore', '')::integer, v_observacoes,
    nullif(p_dados->>'vacina_id', '')::uuid, nullif(p_dados->>'vacina_nome', ''),
    nullif(p_dados->>'vacina_fabricante', ''), nullif(p_dados->>'vacina_lote', ''),
    nullif(p_dados->>'outro_nome', ''), nullif(p_dados->>'peso_kg', '')::numeric,
    nullif(p_dados->>'dose', '')::numeric, nullif(p_dados->>'dose_unidade', ''),
    nullif(p_dados->>'peso_referencia_kg', '')::numeric, nullif(p_dados->>'via_aplicacao', ''),
    nullif(p_dados->>'validade', '')::date, nullif(p_dados->>'carencia_dias', '')::integer,
    nullif(p_dados->>'vermifugo_id', '')::uuid, nullif(p_dados->>'vermifugo_nome', ''),
    nullif(p_dados->>'vermifugo_principio_ativo', ''), nullif(p_dados->>'medicamento_id', '')::uuid,
    nullif(p_dados->>'medicamento_nome', ''), nullif(p_dados->>'medicamento_principio_ativo', ''),
    nullif(p_dados->>'enfermidade', ''), v_produto_id, v_quantidade
  );

  select to_jsonb(m) into v_existente from public.manejos m where m.id = v_manejo_id;
  return v_existente;
end;
$$;

create or replace function public.registrar_manejos_com_estoque(p_itens jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_item jsonb;
  v_resultados jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_itens) <> 'array' then raise exception 'Os itens do manejo em lote devem ser uma lista.'; end if;
  for v_item in select value from jsonb_array_elements(p_itens) loop
    v_resultados := v_resultados || jsonb_build_array(public.registrar_manejo_com_estoque(v_item, null));
  end loop;
  return v_resultados;
end;
$$;

create or replace function public.atualizar_manejo_com_estoque(
  p_id uuid, p_fazenda_id uuid, p_dados jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_antigo public.manejos%rowtype;
  v_mov public.farmacia_movimentacoes%rowtype;
  v_novo_produto uuid := nullif(p_dados->>'farmacia_produto_id', '')::uuid;
  v_nova_qtd numeric(12,3) := nullif(coalesce(p_dados->>'farmacia_quantidade', p_dados->>'dose'), '')::numeric;
begin
  select * into v_antigo from public.manejos where id = p_id and fazenda_id = p_fazenda_id for update;
  if not found then raise exception 'Manejo não encontrado.'; end if;

  if not exists (select 1 from public.fazendas f where f.id = p_fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if v_novo_produto is not null and (v_nova_qtd is null or v_nova_qtd <= 0) then
    raise exception 'Informe uma quantidade válida para o consumo da farmácia.';
  end if;

  for v_mov in select * from public.farmacia_movimentacoes where manejo_id = p_id and fazenda_id = p_fazenda_id for update loop
    if v_mov.farmacia_lote_id is not null then
      update public.farmacia_lotes set quantidade_atual = quantidade_atual + v_mov.quantidade, atualizado_em = now()
      where id = v_mov.farmacia_lote_id;
    else
      insert into public.farmacia_lotes (
        fazenda_id, produto_id, codigo_lote, quantidade_inicial, quantidade_atual, observacoes
      ) values (
        p_fazenda_id, v_mov.produto_id, 'LEGADO-DEVOLUCAO', v_mov.quantidade, v_mov.quantidade,
        'Lote criado ao devolver consumo antigo sem rastreio de lote.'
      );
    end if;
  end loop;

  delete from public.farmacia_movimentacoes where manejo_id = p_id and fazenda_id = p_fazenda_id;

  update public.farmacia_produtos p
     set estoque = coalesce((
       select sum(l.quantidade_atual) from public.farmacia_lotes l
       where l.produto_id = p.id and l.fazenda_id = p.fazenda_id
     ), 0), atualizado_em = now()
   where p.fazenda_id = p_fazenda_id;

  if v_novo_produto is not null then
    perform public.farmacia_consumir_fefo(
      p_fazenda_id, v_novo_produto, v_nova_qtd,
      nullif(p_dados->>'data', '')::date, null,
      coalesce(nullif(p_dados->>'animal_id', '')::uuid, v_antigo.animal_id),
      p_id, gen_random_uuid(), nullif(p_dados->>'observacoes', ''), null
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
   where id = p_id and fazenda_id = p_fazenda_id;

  return (select to_jsonb(m) from public.manejos m where m.id = p_id);
end;
$$;

create or replace function public.excluir_manejo_com_estoque(p_id uuid, p_fazenda_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_mov public.farmacia_movimentacoes%rowtype;
begin
  for v_mov in select * from public.farmacia_movimentacoes where manejo_id = p_id and fazenda_id = p_fazenda_id for update loop
    if v_mov.farmacia_lote_id is not null then
      update public.farmacia_lotes set quantidade_atual = quantidade_atual + v_mov.quantidade, atualizado_em = now()
      where id = v_mov.farmacia_lote_id;
    else
      insert into public.farmacia_lotes (
        fazenda_id, produto_id, codigo_lote, quantidade_inicial, quantidade_atual, observacoes
      ) values (
        p_fazenda_id, v_mov.produto_id, 'LEGADO-DEVOLUCAO', v_mov.quantidade, v_mov.quantidade,
        'Lote criado ao devolver consumo antigo sem rastreio de lote.'
      );
    end if;
  end loop;

  delete from public.farmacia_movimentacoes where manejo_id = p_id and fazenda_id = p_fazenda_id;

  update public.farmacia_produtos p
     set estoque = coalesce((
       select sum(l.quantidade_atual) from public.farmacia_lotes l
       where l.produto_id = p.id and l.fazenda_id = p.fazenda_id
     ), 0), atualizado_em = now()
   where p.fazenda_id = p_fazenda_id;

  delete from public.manejos where id = p_id and fazenda_id = p_fazenda_id;
end;
$$;

grant execute on function public.registrar_manejo_com_estoque(jsonb, numeric) to authenticated;
grant execute on function public.registrar_manejos_com_estoque(jsonb) to authenticated;
grant execute on function public.atualizar_manejo_com_estoque(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_manejo_com_estoque(uuid, uuid) to authenticated;
