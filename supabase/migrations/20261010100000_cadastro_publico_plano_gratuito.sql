-- Cadastro público: novas contas recebem automaticamente o plano gratuito.
-- Fazendas/contas existentes não são alteradas por esta migração.
insert into public.planos_produtor (id, nome, limite_animais, preco_mensal, ativo)
values ('free_10', 'Gratuito (até 10 animais)', 10, 0, true)
on conflict (id) do update
set nome = excluded.nome,
    limite_animais = excluded.limite_animais,
    preco_mensal = excluded.preco_mensal,
    ativo = true;

create or replace function public.atribuir_plano_gratuito_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.planos_pendentes_produtor (usuario_id, plano_id, atualizado_em)
  values (new.id, 'free_10', now())
  on conflict (usuario_id) do nothing;
  return new;
end;
$$;

drop trigger if exists atribuir_plano_gratuito_novo_usuario on auth.users;
create trigger atribuir_plano_gratuito_novo_usuario
after insert on auth.users
for each row execute function public.atribuir_plano_gratuito_novo_usuario();

-- Recarrega o esquema exposto pelo PostgREST após a migração.
notify pgrst, 'reload schema';
