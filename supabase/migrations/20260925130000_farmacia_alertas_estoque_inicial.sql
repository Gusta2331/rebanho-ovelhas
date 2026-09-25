create or replace function public.farmacia_gerar_alertas_estoque()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  p record;
  v_total integer := 0;
begin
  for p in
    select id, fazenda_id, nome, estoque, estoque_minimo,
           coalesce(unidade_estoque, unidade) as unidade
    from public.farmacia_produtos
    where ativo = true and estoque <= estoque_minimo and estoque_minimo > 0
  loop
    insert into public.farmacia_alertas (
      fazenda_id, produto_id, tipo, titulo, mensagem, chave, aberto
    ) values (
      p.fazenda_id, p.id, 'estoque_baixo', 'Estoque baixo',
      'O produto "' || p.nome || '" está no estoque mínimo (' ||
        trim(to_char(p.estoque_minimo, 'FM999999990.###')) || ' ' ||
        p.unidade || ').',
      'estoque-minimo', true
    )
    on conflict (fazenda_id, produto_id, tipo, chave)
    do update set aberto = true, resolvido_em = null, mensagem = excluded.mensagem;

    v_total := v_total + 1;
  end loop;

  return v_total;
end;
$$;

grant execute on function public.farmacia_gerar_alertas_estoque() to authenticated;
