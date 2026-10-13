-- Permite ao usuário limpar a visualização do próprio histórico sem apagar
-- os registros financeiros necessários à confirmação e auditoria dos pagamentos.
alter table public.pagamentos_planos
  add column if not exists visivel_usuario boolean not null default true;

create or replace function public.ocultar_historico_pagamentos_plano(
  p_tipo text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_usuario_id uuid := auth.uid();
  v_quantidade integer := 0;
begin
  if v_usuario_id is null then
    raise exception 'Faça login para limpar o histórico.';
  end if;

  if p_tipo not in ('pendentes', 'todos') then
    raise exception 'Tipo de limpeza inválido.';
  end if;

  if p_tipo = 'pendentes' then
    update public.pagamentos_planos
       set visivel_usuario = false,
           atualizado_em = now()
     where usuario_id = v_usuario_id
       and visivel_usuario = true
       and status in ('criado', 'pendente');
  else
    update public.pagamentos_planos
       set visivel_usuario = false,
           atualizado_em = now()
     where usuario_id = v_usuario_id
       and visivel_usuario = true;
  end if;

  get diagnostics v_quantidade = row_count;
  return v_quantidade;
end;
$$;

revoke all on function public.ocultar_historico_pagamentos_plano(text)
  from public, anon;
grant execute on function public.ocultar_historico_pagamentos_plano(text)
  to authenticated;

notify pgrst, 'reload schema';
