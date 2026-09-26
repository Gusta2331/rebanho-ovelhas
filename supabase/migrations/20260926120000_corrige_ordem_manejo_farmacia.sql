-- Corrige a ordem do registro: o manejo precisa existir antes da movimentação
-- da farmácia, pois farmacia_movimentacoes.manejo_id possui FK para manejos.id.

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
  v_quantidade numeric(12,3) := coalesce(
    p_quantidade,
    nullif(p_dados->>'farmacia_quantidade', '')::numeric,
    nullif(p_dados->>'dose', '')::numeric
  );
  v_data date := nullif(p_dados->>'data', '')::date;
  v_observacoes text := nullif(p_dados->>'observacoes', '');
  v_existente jsonb;
begin
  select to_jsonb(m) into v_existente
  from public.manejos m
  where m.id = v_manejo_id
    and m.fazenda_id = v_fazenda_id;

  if v_existente is not null then
    return v_existente;
  end if;

  if not exists (
    select 1 from public.fazendas f
    where f.id = v_fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if not exists (
    select 1 from public.animais a
    where a.id = v_animal_id
      and a.fazenda_id = v_fazenda_id
      and a.status = 'ativo'
  ) then
    raise exception 'O animal selecionado não está ativo ou não pertence à fazenda.';
  end if;

  -- Primeiro cria o manejo, pois a movimentação da farmácia referencia este ID.
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

  -- Depois baixa o estoque usando FEFO.
  -- Se o estoque falhar, toda a transação é revertida, inclusive o manejo.
  if v_produto_id is not null then
    perform public.farmacia_consumir_fefo(
      v_fazenda_id,
      v_produto_id,
      v_quantidade,
      v_data,
      null,
      v_animal_id,
      v_manejo_id,
      gen_random_uuid(),
      coalesce(
        v_observacoes,
        'Consumo registrado pelo manejo sanitário.'
      ),
      null
    );
  end if;

  select to_jsonb(m) into v_existente
  from public.manejos m
  where m.id = v_manejo_id;

  return v_existente;
end;
$$;

grant execute on function public.registrar_manejo_com_estoque(jsonb, numeric)
  to authenticated;
