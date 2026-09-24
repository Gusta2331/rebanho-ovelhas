-- Cadastro idempotente de animais criado sem internet; valida sempre a fazenda
-- do usuário autenticado, mesmo que a fila local tenha sido alterada.
create or replace function public.sincronizar_animal(p_dados jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
  v_animal_id uuid := (p_dados->>'id')::uuid;
  v_rebanho_id uuid := (p_dados->>'rebanho_id')::uuid;
  v_raca_id uuid;
  v_origem text := coalesce(p_dados->>'origem', 'nascido');
  v_brinco integer := (p_dados->>'brinco')::integer;
  v_valor numeric := nullif(p_dados->>'valor_aquisicao', '')::numeric;
  v_data_compra date := nullif(p_dados->>'data_aquisicao', '')::date;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  select id into v_fazenda_id from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if v_fazenda_id is null then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;
  if exists (select 1 from public.animais where id = v_animal_id) then
    return v_animal_id;
  end if;
  if not exists (select 1 from public.rebanhos where id = v_rebanho_id
      and fazenda_id = v_fazenda_id and ativo = true) then
    raise exception 'O rebanho selecionado não pertence à fazenda atual ou está inativo.';
  end if;
  if exists (select 1 from public.animais where fazenda_id = v_fazenda_id and brinco = v_brinco) then
    raise exception 'O brinco % já foi utilizado por outro animal.', v_brinco;
  end if;
  if v_origem not in ('nascido', 'comprado') then raise exception 'Origem do animal inválida.'; end if;
  if v_origem = 'comprado' and (v_data_compra is null or v_valor is null or v_valor <= 0) then
    raise exception 'Informe a data e o valor da compra.';
  end if;
  if nullif(trim(p_dados->>'raca_nome'), '') is not null then
    select id into v_raca_id from public.racas
     where fazenda_id = v_fazenda_id and lower(trim(nome)) = lower(trim(p_dados->>'raca_nome'))
       and ativo = true limit 1;
    if v_raca_id is null then
      insert into public.racas(id, fazenda_id, nome, ativo)
      values (gen_random_uuid(), v_fazenda_id, trim(p_dados->>'raca_nome'), true)
      returning id into v_raca_id;
    end if;
  end if;
  if nullif(p_dados->>'mae_id', '') is not null and not exists (
    select 1 from public.animais where id = (p_dados->>'mae_id')::uuid and fazenda_id = v_fazenda_id
  ) then raise exception 'A mãe informada não pertence à fazenda atual.'; end if;
  if nullif(p_dados->>'pai_id', '') is not null and not exists (
    select 1 from public.animais where id = (p_dados->>'pai_id')::uuid and fazenda_id = v_fazenda_id
  ) then raise exception 'O pai informado não pertence à fazenda atual.'; end if;

  insert into public.animais (
    id, fazenda_id, rebanho_id, brinco, nome, sexo, raca_id,
    data_nascimento, status, data_entrada, data_saida, observacoes,
    foto_url, mae_id, pai_id, origem, data_aquisicao, valor_aquisicao,
    vendedor, denticao, denticao_data, denticao_observacoes
  ) values (
    v_animal_id, v_fazenda_id, v_rebanho_id, v_brinco,
    nullif(trim(p_dados->>'nome'), ''), p_dados->>'sexo', v_raca_id,
    nullif(p_dados->>'data_nascimento', '')::timestamptz,
    p_dados->>'status', nullif(p_dados->>'data_entrada', '')::timestamptz,
    nullif(p_dados->>'data_saida', '')::timestamptz,
    nullif(trim(p_dados->>'observacoes'), ''), p_dados->>'foto_url',
    nullif(p_dados->>'mae_id', '')::uuid, nullif(p_dados->>'pai_id', '')::uuid,
    v_origem, case when v_origem = 'comprado' then v_data_compra end,
    case when v_origem = 'comprado' then v_valor end,
    case when v_origem = 'comprado' then nullif(trim(p_dados->>'vendedor'), '') end,
    nullif(trim(p_dados->>'denticao'), ''),
    nullif(p_dados->>'denticao_data', '')::date,
    nullif(trim(p_dados->>'denticao_observacoes'), '')
  );

  if v_origem = 'comprado' then
    insert into public.financeiro_lancamentos (
      id, fazenda_id, tipo, categoria, descricao, valor, data, lote_id,
      animal_id, observacoes, origem_automatica
    ) values (
      gen_random_uuid(), v_fazenda_id, 'despesa', 'Compra de animal',
      'Compra do animal brinco ' || lpad(v_brinco::text, 3, '0'),
      v_valor, v_data_compra, v_rebanho_id, v_animal_id,
      nullif(trim('Vendedor: ' || coalesce(p_dados->>'vendedor', '')), 'Vendedor: '), true
    ) on conflict do nothing;
  end if;
  return v_animal_id;
end;
$$;

revoke all on function public.sincronizar_animal(jsonb) from public;
grant execute on function public.sincronizar_animal(jsonb) to authenticated;
