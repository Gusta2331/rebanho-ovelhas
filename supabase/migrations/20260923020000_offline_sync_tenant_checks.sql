-- Validate optional foreign keys in SECURITY DEFINER offline RPCs so callers
-- cannot attach records from another farm to their own operations.

create or replace function public.sincronizar_movimentacao_farmacia(
  p_id uuid,
  p_fazenda_id uuid,
  p_produto_id uuid,
  p_tipo text,
  p_quantidade numeric,
  p_data date,
  p_lote_id uuid default null,
  p_animal_id uuid default null,
  p_observacoes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estoque numeric;
  v_novo numeric;
begin
  if not exists (
    select 1 from public.fazendas
    where id = p_fazenda_id and proprietario_id = auth.uid() and ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if exists (select 1 from public.farmacia_movimentacoes where id = p_id) then
    return;
  end if;

  if p_tipo not in ('entrada', 'saida') or p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Movimentação inválida.';
  end if;

  if p_lote_id is not null and not exists (
    select 1 from public.rebanhos
    where id = p_lote_id and fazenda_id = p_fazenda_id
  ) then
    raise exception 'O lote informado não pertence à fazenda atual.';
  end if;

  if p_animal_id is not null and not exists (
    select 1 from public.animais
    where id = p_animal_id and fazenda_id = p_fazenda_id
  ) then
    raise exception 'O animal informado não pertence à fazenda atual.';
  end if;

  select estoque into v_estoque
  from public.farmacia_produtos
  where id = p_produto_id and fazenda_id = p_fazenda_id and ativo = true
  for update;

  if v_estoque is null then
    raise exception 'Produto não encontrado.';
  end if;

  if p_tipo = 'entrada' then
    v_novo := v_estoque + p_quantidade;
  else
    v_novo := v_estoque - p_quantidade;
    if v_novo < 0 then
      raise exception 'Estoque insuficiente.';
    end if;
  end if;

  update public.farmacia_produtos
  set estoque = v_novo, atualizado_em = now()
  where id = p_produto_id and fazenda_id = p_fazenda_id;

  insert into public.farmacia_movimentacoes (
    id, fazenda_id, produto_id, tipo, quantidade, data,
    lote_id, animal_id, observacoes
  ) values (
    p_id, p_fazenda_id, p_produto_id, p_tipo, p_quantidade, p_data,
    p_lote_id, p_animal_id, p_observacoes
  )
  on conflict (id) do nothing;
end;
$$;

create or replace function public.sincronizar_manejo_programado(
  p_id uuid,
  p_fazenda_id uuid,
  p_tipo text,
  p_data_programada date,
  p_observacoes text,
  p_animal_ids uuid[],
  p_outro_nome text default null,
  p_vacina_id uuid default null,
  p_vacina_nome text default null,
  p_vacina_fabricante text default null,
  p_dose numeric default null,
  p_dose_unidade text default null,
  p_peso_referencia_kg numeric default null,
  p_via_aplicacao text default null,
  p_validade date default null,
  p_carencia_dias integer default null,
  p_vermifugo_id uuid default null,
  p_vermifugo_nome text default null,
  p_medicamento_id uuid default null,
  p_medicamento_nome text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_animal uuid;
begin
  if not exists (
    select 1 from public.fazendas
    where id = p_fazenda_id and proprietario_id = auth.uid() and ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  if coalesce(array_length(p_animal_ids, 1), 0) = 0 then
    raise exception 'Nenhum animal informado.';
  end if;

  if exists (
    select 1
    from unnest(p_animal_ids) as selecionado(animal_id)
    where not exists (
      select 1 from public.animais a
      where a.id = selecionado.animal_id
        and a.fazenda_id = p_fazenda_id
        and a.status = 'ativo'
    )
  ) then
    raise exception 'Todos os animais precisam pertencer à fazenda atual e estar ativos.';
  end if;

  if p_vacina_id is not null and not exists (
    select 1 from public.vacinas
    where id = p_vacina_id and fazenda_id = p_fazenda_id
  ) then
    raise exception 'A vacina informada não pertence à fazenda atual.';
  end if;

  if p_vermifugo_id is not null and not exists (
    select 1 from public.vermifugos
    where id = p_vermifugo_id and fazenda_id = p_fazenda_id
  ) then
    raise exception 'O vermífugo informado não pertence à fazenda atual.';
  end if;

  if p_medicamento_id is not null and not exists (
    select 1 from public.medicamentos
    where id = p_medicamento_id and fazenda_id = p_fazenda_id
  ) then
    raise exception 'O medicamento informado não pertence à fazenda atual.';
  end if;

  insert into public.manejos_programados (
    id, fazenda_id, tipo, data_programada, observacoes, outro_nome,
    vacina_id, vacina_nome, vacina_fabricante,
    dose, dose_unidade, peso_referencia_kg, via_aplicacao,
    validade, carencia_dias, vermifugo_id, vermifugo_nome,
    medicamento_id, medicamento_nome
  ) values (
    p_id, p_fazenda_id, p_tipo, p_data_programada,
    nullif(trim(p_observacoes), ''), nullif(trim(p_outro_nome), ''),
    p_vacina_id, nullif(trim(p_vacina_nome), ''),
    nullif(trim(p_vacina_fabricante), ''), p_dose,
    nullif(trim(p_dose_unidade), ''), p_peso_referencia_kg,
    nullif(trim(p_via_aplicacao), ''), p_validade, p_carencia_dias,
    p_vermifugo_id, nullif(trim(p_vermifugo_nome), ''),
    p_medicamento_id, nullif(trim(p_medicamento_nome), '')
  )
  on conflict (id) do nothing;

  foreach v_animal in array p_animal_ids loop
    insert into public.manejos_programados_animais (
      id, manejo_programado_id, animal_id
    ) values (
      gen_random_uuid(), p_id, v_animal
    )
    on conflict (manejo_programado_id, animal_id) do nothing;
  end loop;
end;
$$;

grant execute on function public.sincronizar_movimentacao_farmacia(uuid, uuid, uuid, text, numeric, date, uuid, uuid, text) to authenticated;
grant execute on function public.sincronizar_manejo_programado(uuid, uuid, text, date, text, uuid[], text, uuid, text, text, numeric, text, numeric, text, date, integer, uuid, text, uuid, text) to authenticated;
