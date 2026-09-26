-- Limpeza controlada do historico da farmacia.
-- Mantem os cadastros de produtos e os registros de manejo.
create or replace function public.apagar_historico_produto_farmacia(
  p_produto_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  select p.fazenda_id
    into v_fazenda_id
  from public.farmacia_produtos p
  where p.id = p_produto_id;

  if v_fazenda_id is null then
    raise exception 'Produto não encontrado.';
  end if;

  if not exists (
    select 1
    from public.fazendas f
    where f.id = v_fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  ) then
    raise exception 'Fazenda não autorizada.';
  end if;

  delete from public.farmacia_alertas
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  delete from public.farmacia_movimentacoes
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  delete from public.farmacia_lotes
   where produto_id = p_produto_id
     and fazenda_id = v_fazenda_id;

  update public.farmacia_produtos
     set estoque = 0,
         atualizado_em = now()
   where id = p_produto_id
     and fazenda_id = v_fazenda_id;
end;
$$;

create or replace function public.apagar_historico_farmacia()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  select f.id
    into v_fazenda_id
  from public.fazendas f
  where f.proprietario_id = auth.uid()
    and f.ativo = true
  order by f.created_at
  limit 1;

  if v_fazenda_id is null then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  delete from public.farmacia_alertas
   where fazenda_id = v_fazenda_id;

  delete from public.farmacia_movimentacoes
   where fazenda_id = v_fazenda_id;

  delete from public.farmacia_lotes
   where fazenda_id = v_fazenda_id;

  update public.farmacia_produtos
     set estoque = 0,
         atualizado_em = now()
   where fazenda_id = v_fazenda_id;
end;
$$;

grant execute on function public.apagar_historico_produto_farmacia(uuid)
  to authenticated;

grant execute on function public.apagar_historico_farmacia()
  to authenticated;
