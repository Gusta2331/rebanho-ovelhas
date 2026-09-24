-- Corrige a exclusão de animais para não acessar diretamente storage.objects.
-- As fotos são removidas pela API oficial do Supabase Storage no aplicativo.
create or replace function public.excluir_animal_e_historico(p_animal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazenda_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select id into v_fazenda_id
  from public.fazendas
  where proprietario_id = auth.uid()
    and ativo = true
  limit 1;

  if v_fazenda_id is null then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  if not exists (
    select 1
    from public.animais
    where id = p_animal_id
      and fazenda_id = v_fazenda_id
  ) then
    raise exception 'Animal não encontrado nesta fazenda.';
  end if;

  -- Cordeiros permanecem no rebanho; apenas a filiação ao animal excluído é removida.
  update public.animais
  set
    mae_id = case when mae_id = p_animal_id then null else mae_id end,
    pai_id = case when pai_id = p_animal_id then null else pai_id end
  where fazenda_id = v_fazenda_id
    and (mae_id = p_animal_id or pai_id = p_animal_id);

  delete from public.reproducao_coberturas
  where reproducao_id in (
    select id
    from public.reproducoes
    where fazenda_id = v_fazenda_id
      and (mae_id = p_animal_id or pai_id = p_animal_id)
  );

  delete from public.reproducao_nascimentos
  where reproducao_id in (
    select id
    from public.reproducoes
    where fazenda_id = v_fazenda_id
      and (mae_id = p_animal_id or pai_id = p_animal_id)
  )
  or animal_id = p_animal_id;

  delete from public.reproducoes
  where fazenda_id = v_fazenda_id
    and (mae_id = p_animal_id or pai_id = p_animal_id);

  delete from public.manejos_programados_animais
  where animal_id = p_animal_id;

  delete from public.animal_transferencias
  where animal_id = p_animal_id;

  delete from public.manejos
  where fazenda_id = v_fazenda_id
    and animal_id = p_animal_id;

  delete from public.vendas_animais
  where fazenda_id = v_fazenda_id
    and animal_id = p_animal_id;

  delete from public.farmacia_movimentacoes
  where fazenda_id = v_fazenda_id
    and animal_id = p_animal_id;

  delete from public.financeiro_lancamentos
  where fazenda_id = v_fazenda_id
    and animal_id = p_animal_id;

  -- A foto do animal é removida pelo Storage API no aplicativo.
  -- Não fazer DELETE direto em storage.objects.

  delete from public.animais
  where id = p_animal_id
    and fazenda_id = v_fazenda_id;
end;
$$;

revoke all on function public.excluir_animal_e_historico(uuid) from public;
grant execute on function public.excluir_animal_e_historico(uuid) to authenticated;
