-- Dados dentários e operações de edição/exclusão atômicas do animal.
alter table public.animais
  add column if not exists denticao text,
  add column if not exists denticao_data date,
  add column if not exists denticao_observacoes text;

alter table public.manejos
  add column if not exists enfermidade text;

create or replace function public.atualizar_animal_com_origem(
  p_animal_id uuid,
  p_rebanho_id uuid,
  p_brinco integer,
  p_nome text,
  p_sexo text,
  p_raca_id uuid,
  p_data_nascimento timestamptz,
  p_status text,
  p_data_entrada timestamptz,
  p_data_saida timestamptz,
  p_observacoes text,
  p_foto_url text,
  p_mae_id uuid,
  p_pai_id uuid,
  p_origem text,
  p_data_aquisicao date,
  p_valor_aquisicao numeric,
  p_vendedor text,
  p_denticao text,
  p_denticao_data date,
  p_denticao_observacoes text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
  v_animal public.animais%rowtype;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  select id into v_fazenda_id from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if v_fazenda_id is null then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;
  select * into v_animal from public.animais
   where id = p_animal_id and fazenda_id = v_fazenda_id for update;
  if not found then raise exception 'Animal não encontrado nesta fazenda.'; end if;
  if not exists (select 1 from public.rebanhos
    where id = p_rebanho_id and fazenda_id = v_fazenda_id and ativo = true) then
    raise exception 'O lote selecionado não pertence à fazenda atual ou está inativo.';
  end if;
  if exists (select 1 from public.animais where fazenda_id = v_fazenda_id
    and brinco = p_brinco and id <> p_animal_id) then
    raise exception 'O brinco % já foi utilizado por outro animal.', p_brinco;
  end if;
  if p_raca_id is not null and not exists (select 1 from public.racas
    where id = p_raca_id and fazenda_id = v_fazenda_id and ativo = true) then
    raise exception 'A raça selecionada não pertence à fazenda atual.';
  end if;
  if p_origem not in ('nascido', 'comprado') then raise exception 'Origem do animal inválida.'; end if;
  if p_origem = 'comprado' and (p_data_aquisicao is null or p_valor_aquisicao is null or p_valor_aquisicao <= 0) then
    raise exception 'Informe a data e um valor de compra maior que zero.';
  end if;

  update public.animais set
    rebanho_id = p_rebanho_id,
    brinco = p_brinco,
    nome = nullif(trim(p_nome), ''),
    sexo = p_sexo,
    raca_id = p_raca_id,
    data_nascimento = p_data_nascimento,
    status = p_status,
    data_entrada = coalesce(p_data_entrada, v_animal.data_entrada),
    data_saida = p_data_saida,
    observacoes = nullif(trim(p_observacoes), ''),
    foto_url = p_foto_url,
    mae_id = p_mae_id,
    pai_id = p_pai_id,
    origem = p_origem,
    data_aquisicao = case when p_origem = 'comprado' then p_data_aquisicao else null end,
    valor_aquisicao = case when p_origem = 'comprado' then p_valor_aquisicao else null end,
    vendedor = case when p_origem = 'comprado' then nullif(trim(p_vendedor), '') else null end,
    denticao = nullif(trim(p_denticao), ''),
    denticao_data = p_denticao_data,
    denticao_observacoes = nullif(trim(p_denticao_observacoes), ''),
    atualizado_em = now()
  where id = p_animal_id and fazenda_id = v_fazenda_id;

  if p_origem = 'comprado' then
    insert into public.financeiro_lancamentos (
      id, fazenda_id, tipo, categoria, descricao, valor, data, lote_id,
      animal_id, observacoes, origem_automatica
    ) values (
      gen_random_uuid(), v_fazenda_id, 'despesa', 'Compra de animal',
      'Compra do animal brinco ' || lpad(p_brinco::text, 3, '0'),
      p_valor_aquisicao, p_data_aquisicao, p_rebanho_id, p_animal_id,
      nullif(trim('Vendedor: ' || coalesce(p_vendedor, '')), 'Vendedor: '), true
    ) on conflict (animal_id, categoria)
      where origem_automatica = true and tipo = 'despesa'
        and categoria = 'Compra de animal' and animal_id is not null
      do update set valor = excluded.valor, data = excluded.data,
        lote_id = excluded.lote_id, observacoes = excluded.observacoes,
        descricao = excluded.descricao;
  else
    delete from public.financeiro_lancamentos
     where animal_id = p_animal_id and origem_automatica = true
       and tipo = 'despesa' and categoria = 'Compra de animal';
  end if;
end;
$$;

create or replace function public.excluir_animal_e_historico(p_animal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  select id into v_fazenda_id from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if v_fazenda_id is null then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;
  if not exists (select 1 from public.animais
    where id = p_animal_id and fazenda_id = v_fazenda_id) then
    raise exception 'Animal não encontrado nesta fazenda.';
  end if;

  -- Cordeiros permanecem no rebanho; apenas a filiação ao animal excluído é removida.
  update public.animais set
    mae_id = case when mae_id = p_animal_id then null else mae_id end,
    pai_id = case when pai_id = p_animal_id then null else pai_id end
  where fazenda_id = v_fazenda_id and (mae_id = p_animal_id or pai_id = p_animal_id);

  delete from public.reproducao_coberturas
   where reproducao_id in (select id from public.reproducoes
     where fazenda_id = v_fazenda_id and (mae_id = p_animal_id or pai_id = p_animal_id));
  delete from public.reproducao_nascimentos
   where reproducao_id in (select id from public.reproducoes
     where fazenda_id = v_fazenda_id and (mae_id = p_animal_id or pai_id = p_animal_id))
      or animal_id = p_animal_id;
  delete from public.reproducoes where fazenda_id = v_fazenda_id
    and (mae_id = p_animal_id or pai_id = p_animal_id);
  delete from public.manejos_programados_animais where animal_id = p_animal_id;
  delete from public.animal_transferencias where animal_id = p_animal_id;
  delete from public.manejos where fazenda_id = v_fazenda_id and animal_id = p_animal_id;
  delete from public.vendas_animais where fazenda_id = v_fazenda_id and animal_id = p_animal_id;
  delete from public.farmacia_movimentacoes where fazenda_id = v_fazenda_id and animal_id = p_animal_id;
  delete from public.financeiro_lancamentos where fazenda_id = v_fazenda_id and animal_id = p_animal_id;
  delete from storage.objects where bucket_id = 'animal-fotos'
    and name like v_fazenda_id::text || '/' || p_animal_id::text || '.%';
  delete from public.animais where id = p_animal_id and fazenda_id = v_fazenda_id;
end;
$$;

revoke all on function public.atualizar_animal_com_origem(
  uuid, uuid, integer, text, text, uuid, timestamptz, text, timestamptz,
  timestamptz, text, text, uuid, uuid, text, date, numeric, text, text, date, text
) from public;
grant execute on function public.atualizar_animal_com_origem(
  uuid, uuid, integer, text, text, uuid, timestamptz, text, timestamptz,
  timestamptz, text, text, uuid, uuid, text, date, numeric, text, text, date, text
) to authenticated;
revoke all on function public.excluir_animal_e_historico(uuid) from public;
grant execute on function public.excluir_animal_e_historico(uuid) to authenticated;
