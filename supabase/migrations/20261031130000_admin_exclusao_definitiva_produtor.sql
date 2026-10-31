-- Exclusao definitiva e isolada de produtor pelo painel administrativo.
-- Mantem historicos de transferencias que envolvam fazendas sobreviventes.

alter table public.transferencias_entre_fazendas
  alter column fazenda_origem_id drop not null,
  alter column fazenda_destino_id drop not null,
  alter column solicitante_id drop not null,
  alter column destinatario_id drop not null,
  alter column lote_origem_id drop not null;

alter table public.transferencias_entre_fazendas
  drop constraint if exists transferencias_entre_fazendas_fazenda_origem_id_fkey,
  drop constraint if exists transferencias_entre_fazendas_fazenda_destino_id_fkey,
  drop constraint if exists transferencias_entre_fazendas_solicitante_id_fkey,
  drop constraint if exists transferencias_entre_fazendas_destinatario_id_fkey,
  drop constraint if exists transferencias_entre_fazendas_lote_origem_id_fkey;

alter table public.transferencias_entre_fazendas
  add constraint transferencias_entre_fazendas_fazenda_origem_id_fkey
    foreign key (fazenda_origem_id) references public.fazendas(id) on delete set null,
  add constraint transferencias_entre_fazendas_fazenda_destino_id_fkey
    foreign key (fazenda_destino_id) references public.fazendas(id) on delete set null,
  add constraint transferencias_entre_fazendas_solicitante_id_fkey
    foreign key (solicitante_id) references auth.users(id) on delete set null,
  add constraint transferencias_entre_fazendas_destinatario_id_fkey
    foreign key (destinatario_id) references auth.users(id) on delete set null,
  add constraint transferencias_entre_fazendas_lote_origem_id_fkey
    foreign key (lote_origem_id) references public.rebanhos(id) on delete set null;

alter table public.transferencias_entre_fazendas_historico
  alter column autor_id drop not null;

alter table public.transferencias_entre_fazendas_historico
  drop constraint if exists transferencias_entre_fazendas_historico_autor_id_fkey;

alter table public.transferencias_entre_fazendas_historico
  add constraint transferencias_entre_fazendas_historico_autor_id_fkey
    foreign key (autor_id) references auth.users(id) on delete set null;

create or replace function public.admin_excluir_produtor(p_usuario_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fazendas uuid[];
  v_fazenda_id uuid;
begin
  if p_usuario_id is null then
    raise exception 'ID do produtor não informado.';
  end if;

  perform 1 from public.usuarios where id = p_usuario_id for update;
  if not found then
    raise exception 'Perfil do produtor não encontrado.';
  end if;

  select coalesce(array_agg(id), '{}'::uuid[])
    into v_fazendas
  from public.fazendas
  where proprietario_id = p_usuario_id;

  -- Bloqueia as fazendas durante toda a operação.
  for v_fazenda_id in
    select f.id from public.fazendas f
    where f.proprietario_id = p_usuario_id
    order by f.id
    for update
  loop
    null;
  end loop;

  if coalesce(array_length(v_fazendas, 1), 0) > 0 then
    -- Remove vínculos de manejos agendados antes dos animais (FK RESTRICT).
    delete from public.manejos_programados_animais mpa
    using public.manejos_programados mp
    where mpa.manejo_programado_id = mp.id
      and mp.fazenda_id = any(v_fazendas);

    delete from public.manejos_programados
    where fazenda_id = any(v_fazendas);

    -- Filhos de reprodução possuem FKs RESTRICT para reprodução/animal.
    delete from public.reproducao_coberturas rc
    using public.reproducoes r
    where rc.reproducao_id = r.id
      and r.fazenda_id = any(v_fazendas);

    delete from public.reproducao_nascimentos rn
    using public.reproducoes r
    where rn.reproducao_id = r.id
      and r.fazenda_id = any(v_fazendas);

    delete from public.reproducao_nascimentos
    where animal_id in (
      select a.id from public.animais a where a.fazenda_id = any(v_fazendas)
    );

    delete from public.reproducoes
    where fazenda_id = any(v_fazendas);

    -- Registros locais com FK RESTRICT são removidos somente dentro das fazendas alvo.
    delete from public.animal_transferencias
    where fazenda_id = any(v_fazendas);

    -- Manejos e movimentações possuem referências RESTRICT/NO ACTION
    -- para animais e lotes, portanto saem antes dos registros principais.
    delete from public.manejos
    where fazenda_id = any(v_fazendas);

    delete from public.movimentacoes_rebanho
    where fazenda_id = any(v_fazendas);

    delete from public.vendas_animais
    where fazenda_id = any(v_fazendas);

    -- Mantém animais de outros produtores, retirando apenas filiação a animais excluídos.
    update public.animais
       set mae_id = null
     where mae_id in (select id from public.animais where fazenda_id = any(v_fazendas));

    update public.animais
       set pai_id = null
     where pai_id in (select id from public.animais where fazenda_id = any(v_fazendas));

    -- Evita bloqueio por autorreferências entre animais da própria fazenda.
    update public.animais
       set mae_id = null, pai_id = null
     where fazenda_id = any(v_fazendas);

    delete from public.animais
    where fazenda_id = any(v_fazendas);

    -- Lotes e fazendas são removidos após seus dependentes.
    delete from public.rebanhos
    where fazenda_id = any(v_fazendas);

    delete from public.fazendas
    where id = any(v_fazendas)
      and proprietario_id = p_usuario_id;
  end if;
end;
$$;

revoke all on function public.admin_excluir_produtor(uuid) from public, anon, authenticated;
grant execute on function public.admin_excluir_produtor(uuid) to service_role;
