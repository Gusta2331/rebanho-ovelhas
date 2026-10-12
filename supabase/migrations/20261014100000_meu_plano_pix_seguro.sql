-- Permite ao cliente consultar o catálogo ativo e apenas a própria atribuição/plano pendente.
-- A ativação de planos pagos continua restrita ao backend após validar o pagamento no provedor.
drop policy if exists "Cliente consulta planos ativos" on public.planos_produtor;
create policy "Cliente consulta planos ativos"
  on public.planos_produtor
  for select
  to authenticated
  using (ativo = true);

drop policy if exists "Cliente consulta plano da própria fazenda" on public.planos_fazenda;
create policy "Cliente consulta plano da própria fazenda"
  on public.planos_fazenda
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.fazendas f
      where f.id = planos_fazenda.fazenda_id
        and f.proprietario_id = auth.uid()
    )
  );

drop policy if exists "Cliente consulta seu plano pendente" on public.planos_pendentes_produtor;
create policy "Cliente consulta seu plano pendente"
  on public.planos_pendentes_produtor
  for select
  to authenticated
  using (usuario_id = auth.uid());

-- Executada apenas pela Edge Function após consultar e validar o status real no Mercado Pago.
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

  select id
    into v_fazenda_id
  from public.fazendas
  where proprietario_id = v_pagamento.usuario_id
    and ativo = true
  order by criado_em asc
  limit 1;

  if v_fazenda_id is not null then
    insert into public.planos_fazenda
      (fazenda_id, plano_id, validade_em, status, atualizado_em)
    values
      (v_fazenda_id, v_pagamento.plano_id, p_validade_em, 'ativo', now())
    on conflict (fazenda_id) do update
      set plano_id = excluded.plano_id,
          validade_em = excluded.validade_em,
          status = 'ativo',
          atualizado_em = now();
  else
    insert into public.planos_pendentes_produtor
      (usuario_id, plano_id, validade_em, atualizado_em)
    values
      (v_pagamento.usuario_id, v_pagamento.plano_id, p_validade_em, now())
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

revoke all on function public.ativar_plano_apos_pagamento(uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.ativar_plano_apos_pagamento(uuid, text, timestamptz) to service_role;

notify pgrst, 'reload schema';
