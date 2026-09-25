create or replace function public.farmacia_gerar_alertas_validade()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lote record;
  v_tipo text;
  v_titulo text;
  v_mensagem text;
  v_chave text;
  v_total integer := 0;
begin
  for v_lote in
    select
      l.id,
      l.fazenda_id,
      l.produto_id,
      l.codigo_lote,
      l.quantidade_atual,
      l.validade,
      p.nome,
      coalesce(p.unidade_estoque, p.unidade) as unidade
    from public.farmacia_lotes l
    join public.farmacia_produtos p on p.id = l.produto_id
    where p.ativo = true
      and l.quantidade_atual > 0
      and l.validade is not null
      and l.validade <= current_date + 30
  loop
    if v_lote.validade < current_date then
      v_tipo := 'produto_vencido';
      v_titulo := 'Produto vencido';
      v_mensagem := 'O produto "' || v_lote.nome || '" está vencido' ||
        case when v_lote.codigo_lote is null then '' else ' (lote ' || v_lote.codigo_lote || ')' end || '.';
      v_chave := 'validade-vencido-' || v_lote.id::text;
    else
      v_tipo := 'validade_proxima';
      v_titulo := 'Validade próxima';
      v_mensagem := 'O produto "' || v_lote.nome || '" vence em ' ||
        to_char(v_lote.validade, 'DD/MM/YYYY') ||
        case when v_lote.codigo_lote is null then '' else ' (lote ' || v_lote.codigo_lote || ')' end || '.';
      v_chave := 'validade-30-dias-' || v_lote.id::text || '-' || v_lote.validade::text;
    end if;

    insert into public.farmacia_alertas (
      fazenda_id, produto_id, tipo, titulo, mensagem, chave, aberto
    ) values (
      v_lote.fazenda_id, v_lote.produto_id, v_tipo, v_titulo, v_mensagem, v_chave, true
    )
    on conflict (fazenda_id, produto_id, tipo, chave)
    do update set aberto = true, resolvido_em = null, mensagem = excluded.mensagem;

    v_total := v_total + 1;
  end loop;

  return v_total;
end;
$$;

grant execute on function public.farmacia_gerar_alertas_validade() to authenticated;
