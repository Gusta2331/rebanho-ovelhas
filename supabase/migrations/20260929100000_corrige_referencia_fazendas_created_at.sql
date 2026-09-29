-- Corrige referência antiga a fazendas.created_at.
-- A tabela fazendas usa criado_em e esta função não precisa ordenar a fazenda.
create or replace function private.usuario_e_dono_fazenda(p_fazenda_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
    select exists (
        select 1
        from public.fazendas f
        where f.id = p_fazenda_id
          and f.proprietario_id = auth.uid()
          and f.ativo = true
    );
$function$;

-- Corrige também a função de limpeza do histórico da Farmácia.
create or replace function public.apagar_historico_farmacia()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_fazenda_id uuid;
begin
  select f.id
    into v_fazenda_id
  from public.fazendas f
  where f.proprietario_id = auth.uid()
    and f.ativo = true
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
$function$;

grant execute on function public.apagar_historico_farmacia() to authenticated;

notify pgrst, 'reload schema';
