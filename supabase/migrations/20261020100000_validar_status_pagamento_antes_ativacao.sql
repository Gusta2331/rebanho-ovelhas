-- Garante que somente cobranças abertas possam ativar um plano.
-- Mantém a ativação idempotente para pagamentos já aprovados.
create or replace function public.ativar_plano_apos_pagamento(
  p_pagamento_id uuid,
  p_provedor_order_id text,
  p_validade_em timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pagamento public.pagamentos_planos%rowtype;
  v_fazenda_id uuid;
  v_validade_atual timestamptz;
  v_validade_final timestamptz;
  v_plano_atual_id text;
  v_duracao_dias integer;
begin
  select *
    into v_pagamento
  from public.pagamentos_planos
  where id = p_pagamento_id
  for update;

  if not found then
    raise exception 'Pagamento não encontrado.';
  end if;

  if v_pagamento.provedor_order_id is distinct from p_provedor_order_id then
    raise exception 'A referência do provedor não corresponde ao pagamento.';
  end if;

  if v_pagamento.status = 'aprovado' then
    return jsonb_build_object('success', true, 'ja_aprovado', true);
  end if;

  if v_pagamento.status not in ('criado', 'pendente') then
    raise exception 'Este pagamento não está aberto para ativação.';
  end if;

  v_duracao_dias := greatest(1, coalesce(v_pagamento.duracao_dias, 30));

  select id
    into v_fazenda_id
  from public.fazendas
  where proprietario_id = v_pagamento.usuario_id
    and ativo = true
  order by criado_em asc
  limit 1;

  if v_fazenda_id is not null then
    select plano_id, validade_em
      into v_plano_atual_id, v_validade_atual
    from public.planos_fazenda
    where fazenda_id = v_fazenda_id;

    if v_pagamento.tipo_operacao = 'upgrade' then
      if v_plano_atual_id is distinct from v_pagamento.plano_anterior_id
        or v_validade_atual is distinct from v_pagamento.validade_anterior
        or v_validade_atual is null
        or v_validade_atual <= now() then
        raise exception 'A assinatura mudou durante o pagamento. O plano não foi alterado; entre em contato com o suporte para verificar a cobrança.';
      end if;
      v_validade_final := v_validade_atual;
    elsif v_pagamento.tipo_operacao = 'renovacao'
      and v_plano_atual_id = v_pagamento.plano_id
      and v_validade_atual > now() then
      v_validade_final := v_validade_atual + make_interval(days => v_duracao_dias);
    else
      v_validade_final := now() + make_interval(days => v_duracao_dias);
    end if;

    insert into public.planos_fazenda
      (fazenda_id, plano_id, validade_em, status, atualizado_em)
    values
      (v_fazenda_id, v_pagamento.plano_id, v_validade_final, 'ativo', now())
    on conflict (fazenda_id) do update
      set plano_id = excluded.plano_id,
          validade_em = excluded.validade_em,
          status = 'ativo',
          atualizado_em = now();
  else
    select plano_id, validade_em
      into v_plano_atual_id, v_validade_atual
    from public.planos_pendentes_produtor
    where usuario_id = v_pagamento.usuario_id;

    if v_pagamento.tipo_operacao = 'upgrade' then
      if v_plano_atual_id is distinct from v_pagamento.plano_anterior_id
        or v_validade_atual is distinct from v_pagamento.validade_anterior
        or v_validade_atual is null
        or v_validade_atual <= now() then
        raise exception 'A assinatura mudou durante o pagamento. O plano não foi alterado; entre em contato com o suporte para verificar a cobrança.';
      end if;
      v_validade_final := v_validade_atual;
    elsif v_pagamento.tipo_operacao = 'renovacao'
      and v_plano_atual_id = v_pagamento.plano_id
      and v_validade_atual > now() then
      v_validade_final := v_validade_atual + make_interval(days => v_duracao_dias);
    else
      v_validade_final := now() + make_interval(days => v_duracao_dias);
    end if;

    insert into public.planos_pendentes_produtor
      (usuario_id, plano_id, validade_em, atualizado_em)
    values
      (v_pagamento.usuario_id, v_pagamento.plano_id, v_validade_final, now())
    on conflict (usuario_id) do update
      set plano_id = excluded.plano_id,
          validade_em = excluded.validade_em,
          atualizado_em = now();
  end if;

  update public.pagamentos_planos
    set status = 'aprovado',
        atualizado_em = now()
  where id = p_pagamento_id;

  return jsonb_build_object('success', true, 'ja_aprovado', false);
end;
$$;

revoke all on function public.ativar_plano_apos_pagamento(uuid, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.ativar_plano_apos_pagamento(uuid, text, timestamptz)
  to service_role;

notify pgrst, 'reload schema';
