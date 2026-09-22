-- Cadastro atômico de animal comprado + lançamento financeiro.
-- Esta migration vem depois de animal_origem_compra.sql porque usa as novas colunas.

create or replace function public.criar_animal_com_compra(
  p_animal_id uuid,
  p_rebanho_id uuid,
  p_brinco integer,
  p_nome text,
  p_sexo text,
  p_raca_id uuid,
  p_data_nascimento timestamptz,
  p_status text,
  p_data_entrada timestamptz,
  p_observacoes text,
  p_foto_url text,
  p_mae_id uuid,
  p_pai_id uuid,
  p_data_aquisicao date,
  p_valor_aquisicao numeric,
  p_vendedor text
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select id
    into v_fazenda_id
    from public.fazendas
   where proprietario_id = auth.uid()
     and ativo = true
   limit 1;

  if v_fazenda_id is null then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  if not exists (
    select 1
      from public.rebanhos
     where id = p_rebanho_id
       and fazenda_id = v_fazenda_id
       and ativo = true
  ) then
    raise exception 'O lote selecionado não pertence à fazenda atual ou está inativo.';
  end if;

  if exists (
    select 1
      from public.animais
     where fazenda_id = v_fazenda_id
       and brinco = p_brinco
  ) then
    raise exception 'O brinco % já foi utilizado por outro animal.', p_brinco;
  end if;

  if p_valor_aquisicao is null or p_valor_aquisicao <= 0 then
    raise exception 'O valor da compra deve ser maior que zero.';
  end if;

  if p_data_aquisicao is null then
    raise exception 'Informe a data da compra.';
  end if;

  insert into public.animais (
    id,
    fazenda_id,
    rebanho_id,
    brinco,
    nome,
    sexo,
    raca_id,
    data_nascimento,
    status,
    data_entrada,
    observacoes,
    foto_url,
    mae_id,
    pai_id,
    origem,
    data_aquisicao,
    valor_aquisicao,
    vendedor
  ) values (
    p_animal_id,
    v_fazenda_id,
    p_rebanho_id,
    p_brinco,
    nullif(trim(p_nome), ''),
    p_sexo,
    p_raca_id,
    p_data_nascimento,
    p_status,
    p_data_entrada,
    nullif(trim(p_observacoes), ''),
    p_foto_url,
    p_mae_id,
    p_pai_id,
    'comprado',
    p_data_aquisicao,
    p_valor_aquisicao,
    nullif(trim(p_vendedor), '')
  );

  insert into public.financeiro_lancamentos (
    id,
    fazenda_id,
    tipo,
    categoria,
    descricao,
    valor,
    data,
    lote_id,
    animal_id,
    observacoes,
    origem_automatica
  ) values (
    gen_random_uuid(),
    v_fazenda_id,
    'despesa',
    'Compra de animal',
    'Compra do animal brinco ' || lpad(p_brinco::text, 3, '0'),
    p_valor_aquisicao,
    p_data_aquisicao,
    p_rebanho_id,
    p_animal_id,
    nullif(trim(concat_ws(' • ',
      case when nullif(trim(p_vendedor), '') is not null then 'Vendedor: ' || trim(p_vendedor) end,
      case when nullif(trim(p_observacoes), '') is not null then trim(p_observacoes) end
    )), ''),
    true
  );

  return p_animal_id;
end;
$$;
