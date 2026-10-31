-- Venda para outra fazenda: a receita e o registro de venda só são criados
-- quando a fazenda compradora aceita a transferência.

alter table public.transferencias_entre_fazendas
  add column if not exists lote_origem_id uuid references public.rebanhos(id) on delete restrict,
  add column if not exists tipo_operacao text not null default 'transferencia'
    check (tipo_operacao in ('transferencia', 'venda')),
  add column if not exists data_venda date,
  add column if not exists tipo_venda text,
  add column if not exists peso_kg numeric(10,2),
  add column if not exists preco_por_kg numeric(10,2),
  add column if not exists valor_total numeric(14,2);

alter table public.transferencias_entre_fazendas
  drop constraint if exists transferencia_entre_fazendas_venda_consistente;
alter table public.transferencias_entre_fazendas
  add constraint transferencia_entre_fazendas_venda_consistente check (
    (tipo_operacao = 'transferencia'
      and data_venda is null and tipo_venda is null and peso_kg is null
      and preco_por_kg is null and valor_total is null)
    or
    (tipo_operacao = 'venda'
      and lote_origem_id is not null and data_venda is not null
      and tipo_venda in ('valor_fechado', 'por_kg')
      and valor_total is not null and valor_total > 0
      and ((tipo_venda = 'valor_fechado' and peso_kg is null and preco_por_kg is null)
        or (tipo_venda = 'por_kg' and peso_kg is not null and peso_kg > 0
          and preco_por_kg is not null and preco_por_kg > 0
          and round(valor_total, 2) = round(peso_kg * preco_por_kg, 2))))
  );

drop function if exists public.solicitar_transferencia_entre_fazendas(uuid, uuid, text);
create or replace function public.solicitar_transferencia_entre_fazendas(
  p_animal_id uuid,
  p_codigo_destino uuid,
  p_observacao text default null,
  p_tipo_operacao text default 'transferencia',
  p_data_venda date default null,
  p_tipo_venda text default null,
  p_peso_kg numeric default null,
  p_preco_por_kg numeric default null,
  p_valor_total numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_origem public.fazendas%rowtype;
  v_destino public.fazendas%rowtype;
  v_animal public.animais%rowtype;
  v_transferencia_id uuid := gen_random_uuid();
  v_valor_calculado numeric(14,2);
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  if p_tipo_operacao not in ('transferencia', 'venda') then raise exception 'Tipo de operação inválido.'; end if;

  select * into v_origem from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if not found then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;
  select * into v_destino from public.fazendas
   where codigo_transferencia = p_codigo_destino and ativo = true;
  if not found then raise exception 'Código de recebimento inválido ou fazenda inativa.'; end if;
  if v_destino.id = v_origem.id then raise exception 'Escolha outra fazenda como destino.'; end if;

  select * into v_animal from public.animais
   where id = p_animal_id and fazenda_id = v_origem.id for update;
  if not found then raise exception 'Animal não encontrado na fazenda de origem.'; end if;
  if v_animal.status <> 'ativo' then raise exception 'Somente animais ativos podem ser transferidos.'; end if;
  if exists (select 1 from public.transferencias_entre_fazendas where animal_id = p_animal_id and status = 'pendente') then
    raise exception 'Já existe uma solicitação pendente para este animal.';
  end if;

  if p_tipo_operacao = 'venda' then
    if p_data_venda is null or p_data_venda > current_date then raise exception 'Informe uma data de venda válida.'; end if;
    if p_tipo_venda not in ('valor_fechado', 'por_kg') then raise exception 'Tipo de venda inválido.'; end if;
    if p_valor_total is null or p_valor_total <= 0 then raise exception 'Informe um valor de venda maior que zero.'; end if;
    if p_tipo_venda = 'valor_fechado' and (p_peso_kg is not null or p_preco_por_kg is not null) then
      raise exception 'Venda por valor fechado não deve informar peso ou preço por kg.';
    end if;
    if p_tipo_venda = 'por_kg' then
      if p_peso_kg is null or p_peso_kg <= 0 or p_preco_por_kg is null or p_preco_por_kg <= 0 then
        raise exception 'Informe peso e preço por kg válidos.';
      end if;
      v_valor_calculado := round(p_peso_kg * p_preco_por_kg, 2);
      if v_valor_calculado <> round(p_valor_total, 2) then raise exception 'O total não corresponde ao peso multiplicado pelo preço por kg.'; end if;
    end if;
  else
    if p_data_venda is not null or p_tipo_venda is not null or p_peso_kg is not null or p_preco_por_kg is not null or p_valor_total is not null then
      raise exception 'Dados de venda não são permitidos em uma transferência simples.';
    end if;
  end if;

  insert into public.transferencias_entre_fazendas (
    id, animal_id, fazenda_origem_id, fazenda_destino_id, solicitante_id, destinatario_id,
    nome_fazenda_origem, nome_fazenda_destino, lote_origem_id, brinco_origem,
    ficha_animal, observacao, tipo_operacao, data_venda, tipo_venda, peso_kg,
    preco_por_kg, valor_total
  ) values (
    v_transferencia_id, v_animal.id, v_origem.id, v_destino.id, auth.uid(), v_destino.proprietario_id,
    v_origem.nome, v_destino.nome, v_animal.rebanho_id, v_animal.brinco,
    jsonb_build_object('id', v_animal.id, 'brinco', v_animal.brinco, 'nome', v_animal.nome,
      'sexo', v_animal.sexo, 'data_nascimento', v_animal.data_nascimento, 'status', v_animal.status),
    nullif(trim(p_observacao), ''), p_tipo_operacao, p_data_venda, p_tipo_venda, p_peso_kg,
    p_preco_por_kg, case when p_valor_total is null then null else round(p_valor_total, 2) end
  );
  insert into public.transferencias_entre_fazendas_historico (transferencia_id, evento, autor_id, detalhes)
  values (v_transferencia_id, 'solicitada', auth.uid(), jsonb_build_object('brinco_origem', v_animal.brinco, 'tipo_operacao', p_tipo_operacao));
  return v_transferencia_id;
end;
$$;

create or replace function public.responder_transferencia_entre_fazendas(
  p_transferencia_id uuid,
  p_aceitar boolean,
  p_rebanho_destino_id uuid default null,
  p_novo_brinco integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_destino public.fazendas%rowtype;
  v_transferencia public.transferencias_entre_fazendas%rowtype;
  v_animal public.animais%rowtype;
  v_brinco_destino integer;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  if p_aceitar is null then raise exception 'Informe se a solicitação será aceita ou rejeitada.'; end if;
  select * into v_destino from public.fazendas where proprietario_id = auth.uid() and ativo = true limit 1;
  if not found then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;
  select * into v_transferencia from public.transferencias_entre_fazendas where id = p_transferencia_id for update;
  if not found then raise exception 'Solicitação de transferência não encontrada.'; end if;
  if v_transferencia.fazenda_destino_id <> v_destino.id then raise exception 'Esta solicitação não pertence à sua fazenda.'; end if;
  if v_transferencia.status <> 'pendente' then raise exception 'Esta solicitação já foi respondida.'; end if;

  if not p_aceitar then
    update public.transferencias_entre_fazendas set status = 'rejeitada', respondido_em = now(), atualizado_em = now() where id = v_transferencia.id;
    insert into public.transferencias_entre_fazendas_historico (transferencia_id, evento, autor_id)
    values (v_transferencia.id, 'rejeitada', auth.uid());
    return v_transferencia.id;
  end if;
  if p_rebanho_destino_id is null then raise exception 'Selecione o lote de destino.'; end if;
  if not exists (select 1 from public.rebanhos where id = p_rebanho_destino_id and fazenda_id = v_destino.id and ativo = true) then
    raise exception 'O lote de destino não pertence à sua fazenda ou está inativo.';
  end if;
  select * into v_animal from public.animais where id = v_transferencia.animal_id and fazenda_id = v_transferencia.fazenda_origem_id for update;
  if not found then raise exception 'O animal não está mais disponível na fazenda de origem.'; end if;
  if v_animal.status <> 'ativo' then raise exception 'O animal não está mais ativo para transferência.'; end if;
  v_brinco_destino := coalesce(p_novo_brinco, v_animal.brinco);
  if v_brinco_destino <= 0 then raise exception 'Informe um brinco válido.'; end if;
  if exists (select 1 from public.animais where fazenda_id = v_destino.id and brinco = v_brinco_destino) then
    raise exception 'O brinco % já foi utilizado na fazenda de destino, inclusive em animais inativos. Informe outro brinco.', v_brinco_destino;
  end if;

  if v_transferencia.tipo_operacao = 'venda' then
    insert into public.vendas_animais (id, fazenda_id, animal_id, lote_id, data_venda, tipo_venda, peso_kg, preco_por_kg, valor_total, comprador, observacoes)
    values (gen_random_uuid(), v_transferencia.fazenda_origem_id, v_animal.id, v_transferencia.lote_origem_id,
      v_transferencia.data_venda, v_transferencia.tipo_venda, v_transferencia.peso_kg,
      v_transferencia.preco_por_kg, v_transferencia.valor_total, v_transferencia.nome_fazenda_destino,
      nullif(trim(concat_ws(' • ', 'Venda com transferência entre fazendas', v_transferencia.observacao)), ''));
    insert into public.financeiro_lancamentos (id, fazenda_id, tipo, categoria, descricao, valor, data, lote_id, animal_id, observacoes, origem_automatica)
    values (gen_random_uuid(), v_transferencia.fazenda_origem_id, 'receita', 'Venda de animal',
      'Venda do animal brinco ' || lpad(v_animal.brinco::text, 3, '0'), v_transferencia.valor_total,
      v_transferencia.data_venda, v_transferencia.lote_origem_id, v_animal.id,
      nullif(trim(concat_ws(' • ',
        case when v_transferencia.tipo_venda = 'por_kg' then 'Venda por kg: ' || to_char(v_transferencia.peso_kg, 'FM999999990.00') || ' kg × R$ ' || to_char(v_transferencia.preco_por_kg, 'FM999999990.00') else 'Venda por valor fechado' end,
        'Comprador: ' || v_transferencia.nome_fazenda_destino, v_transferencia.observacao)), ''), true);
  end if;

  update public.animais set fazenda_id = v_destino.id, rebanho_id = p_rebanho_destino_id,
    brinco = v_brinco_destino, data_entrada = now(), atualizado_em = now()
  where id = v_animal.id and fazenda_id = v_transferencia.fazenda_origem_id;
  update public.transferencias_entre_fazendas set status = 'aceita', respondido_em = now(), concluido_em = now(), brinco_destino = v_brinco_destino, atualizado_em = now() where id = v_transferencia.id;
  insert into public.transferencias_entre_fazendas_historico (transferencia_id, evento, autor_id, detalhes)
  values (v_transferencia.id, 'aceita', auth.uid(), jsonb_build_object('brinco_destino', v_brinco_destino, 'rebanho_destino_id', p_rebanho_destino_id, 'tipo_operacao', v_transferencia.tipo_operacao));
  return v_transferencia.id;
end;
$$;

revoke all on function public.solicitar_transferencia_entre_fazendas(uuid, uuid, text, text, date, text, numeric, numeric, numeric) from public;
grant execute on function public.solicitar_transferencia_entre_fazendas(uuid, uuid, text, text, date, text, numeric, numeric, numeric) to authenticated;
