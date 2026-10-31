-- Transferências de animais entre fazendas.
-- A alteração de proprietário só é feita pela RPC abaixo; o aplicativo nunca
-- finaliza uma transferência localmente ou em mais de uma chamada.

alter table public.fazendas
  add column if not exists codigo_transferencia uuid not null default gen_random_uuid();

create unique index if not exists fazendas_codigo_transferencia_unico_idx
  on public.fazendas(codigo_transferencia);

-- O brinco é uma identificação exclusiva da fazenda, inclusive para animais
-- vendidos, mortos ou descartados. O índice também elimina uma corrida entre
-- duas aceitações simultâneas.
do $$
begin
  if exists (
    select 1
    from public.animais
    group by fazenda_id, brinco
    having count(*) > 1
  ) then
    raise exception
      'Há brincos duplicados na mesma fazenda. Corrija-os antes de aplicar a migração de transferências.';
  end if;
end;
$$;

create unique index if not exists animais_fazenda_brinco_unico_idx
  on public.animais(fazenda_id, brinco);

create table if not exists public.transferencias_entre_fazendas (
  id uuid primary key default gen_random_uuid(),
  animal_id uuid not null,
  fazenda_origem_id uuid not null references public.fazendas(id) on delete restrict,
  fazenda_destino_id uuid not null references public.fazendas(id) on delete restrict,
  solicitante_id uuid not null references auth.users(id) on delete restrict,
  destinatario_id uuid not null references auth.users(id) on delete restrict,
  nome_fazenda_origem text not null,
  nome_fazenda_destino text not null,
  brinco_origem integer not null,
  ficha_animal jsonb not null default '{}'::jsonb,
  observacao text,
  status text not null default 'pendente'
    check (status in ('pendente', 'aceita', 'rejeitada', 'cancelada')),
  solicitado_em timestamptz not null default now(),
  respondido_em timestamptz,
  concluido_em timestamptz,
  brinco_destino integer,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  check (fazenda_origem_id <> fazenda_destino_id)
);

create unique index if not exists transferencia_entre_fazendas_animal_pendente_unica_idx
  on public.transferencias_entre_fazendas(animal_id)
  where status = 'pendente';
create index if not exists transferencia_entre_fazendas_origem_idx
  on public.transferencias_entre_fazendas(fazenda_origem_id, solicitado_em desc);
create index if not exists transferencia_entre_fazendas_destino_idx
  on public.transferencias_entre_fazendas(fazenda_destino_id, solicitado_em desc);

create table if not exists public.transferencias_entre_fazendas_historico (
  id uuid primary key default gen_random_uuid(),
  transferencia_id uuid not null references public.transferencias_entre_fazendas(id) on delete cascade,
  evento text not null check (evento in ('solicitada', 'aceita', 'rejeitada', 'cancelada')),
  autor_id uuid not null references auth.users(id) on delete restrict,
  detalhes jsonb not null default '{}'::jsonb,
  ocorrido_em timestamptz not null default now()
);

create index if not exists transferencia_entre_fazendas_historico_idx
  on public.transferencias_entre_fazendas_historico(transferencia_id, ocorrido_em);

alter table public.transferencias_entre_fazendas enable row level security;
alter table public.transferencias_entre_fazendas_historico enable row level security;

drop policy if exists "transferencias entre fazendas participantes leem" on public.transferencias_entre_fazendas;
create policy "transferencias entre fazendas participantes leem"
  on public.transferencias_entre_fazendas for select to authenticated
  using (
    exists (
      select 1 from public.fazendas f
      where f.proprietario_id = auth.uid() and f.ativo = true
        and f.id in (fazenda_origem_id, fazenda_destino_id)
    )
  );

drop policy if exists "historico transferencia entre fazendas participantes leem" on public.transferencias_entre_fazendas_historico;
create policy "historico transferencia entre fazendas participantes leem"
  on public.transferencias_entre_fazendas_historico for select to authenticated
  using (
    exists (
      select 1
      from public.transferencias_entre_fazendas t
      join public.fazendas f on f.id in (t.fazenda_origem_id, t.fazenda_destino_id)
      where t.id = transferencia_id
        and f.proprietario_id = auth.uid()
        and f.ativo = true
    )
  );

revoke all on table public.transferencias_entre_fazendas from anon, authenticated;
revoke all on table public.transferencias_entre_fazendas_historico from anon, authenticated;
grant select on table public.transferencias_entre_fazendas to authenticated;
grant select on table public.transferencias_entre_fazendas_historico to authenticated;

-- Só revela o nome de uma fazenda quando o remetente já recebeu o código UUID
-- daquela fazenda por outro meio. Não há busca pública de produtores.
create or replace function public.identificar_destino_transferencia(
  p_codigo_destino uuid
)
returns table (fazenda_id uuid, nome text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if not exists (
    select 1 from public.fazendas where proprietario_id = auth.uid() and ativo = true
  ) then
    raise exception 'Nenhuma fazenda ativa foi encontrada.';
  end if;

  return query
    select f.id, f.nome
    from public.fazendas f
    where f.codigo_transferencia = p_codigo_destino and f.ativo = true;
end;
$$;

create or replace function public.solicitar_transferencia_entre_fazendas(
  p_animal_id uuid,
  p_codigo_destino uuid,
  p_observacao text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_origem public.fazendas%rowtype;
  v_destino public.fazendas%rowtype;
  v_animal public.animais%rowtype;
  v_transferencia_id uuid := gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;

  select * into v_origem from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if not found then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;

  select * into v_destino from public.fazendas
   where codigo_transferencia = p_codigo_destino and ativo = true;
  if not found then raise exception 'Código de recebimento inválido ou fazenda inativa.'; end if;
  if v_destino.id = v_origem.id then raise exception 'Escolha outra fazenda como destino.'; end if;

  select * into v_animal from public.animais
   where id = p_animal_id and fazenda_id = v_origem.id for update;
  if not found then raise exception 'Animal não encontrado na fazenda de origem.'; end if;
  if v_animal.status <> 'ativo' then raise exception 'Somente animais ativos podem ser transferidos.'; end if;

  if exists (
    select 1 from public.transferencias_entre_fazendas
    where animal_id = p_animal_id and status = 'pendente'
  ) then raise exception 'Já existe uma solicitação pendente para este animal.'; end if;

  insert into public.transferencias_entre_fazendas (
    id, animal_id, fazenda_origem_id, fazenda_destino_id, solicitante_id,
    destinatario_id, nome_fazenda_origem, nome_fazenda_destino,
    brinco_origem, ficha_animal, observacao
  ) values (
    v_transferencia_id, v_animal.id, v_origem.id, v_destino.id, auth.uid(),
    v_destino.proprietario_id, v_origem.nome, v_destino.nome,
    v_animal.brinco,
    jsonb_build_object(
      'id', v_animal.id,
      'brinco', v_animal.brinco,
      'nome', v_animal.nome,
      'sexo', v_animal.sexo,
      'data_nascimento', v_animal.data_nascimento,
      'status', v_animal.status
    ),
    nullif(trim(p_observacao), '')
  );

  insert into public.transferencias_entre_fazendas_historico (
    transferencia_id, evento, autor_id, detalhes
  ) values (
    v_transferencia_id, 'solicitada', auth.uid(),
    jsonb_build_object('brinco_origem', v_animal.brinco)
  );
  return v_transferencia_id;
end;
$$;

create or replace function public.responder_transferencia_entre_fazendas(
  p_transferencia_id uuid,
  p_aceitar boolean,
  p_rebanho_destino_id uuid default null,
  p_novo_brinco integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_destino public.fazendas%rowtype;
  v_transferencia public.transferencias_entre_fazendas%rowtype;
  v_animal public.animais%rowtype;
  v_brinco_destino integer;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
  if p_aceitar is null then raise exception 'Informe se a solicitação será aceita ou rejeitada.'; end if;

  select * into v_destino from public.fazendas
   where proprietario_id = auth.uid() and ativo = true limit 1;
  if not found then raise exception 'Nenhuma fazenda ativa foi encontrada.'; end if;

  select * into v_transferencia from public.transferencias_entre_fazendas
   where id = p_transferencia_id for update;
  if not found then raise exception 'Solicitação de transferência não encontrada.'; end if;
  if v_transferencia.fazenda_destino_id <> v_destino.id then
    raise exception 'Esta solicitação não pertence à sua fazenda.';
  end if;
  if v_transferencia.status <> 'pendente' then
    raise exception 'Esta solicitação já foi respondida.';
  end if;

  if not p_aceitar then
    update public.transferencias_entre_fazendas set
      status = 'rejeitada', respondido_em = now(), atualizado_em = now()
    where id = v_transferencia.id;
    insert into public.transferencias_entre_fazendas_historico (
      transferencia_id, evento, autor_id
    ) values (v_transferencia.id, 'rejeitada', auth.uid());
    return v_transferencia.id;
  end if;

  if p_rebanho_destino_id is null then raise exception 'Selecione o lote de destino.'; end if;
  if not exists (
    select 1 from public.rebanhos
    where id = p_rebanho_destino_id and fazenda_id = v_destino.id and ativo = true
  ) then raise exception 'O lote de destino não pertence à sua fazenda ou está inativo.'; end if;

  select * into v_animal from public.animais
   where id = v_transferencia.animal_id
     and fazenda_id = v_transferencia.fazenda_origem_id
   for update;
  if not found then raise exception 'O animal não está mais disponível na fazenda de origem.'; end if;
  if v_animal.status <> 'ativo' then raise exception 'O animal não está mais ativo para transferência.'; end if;

  v_brinco_destino := coalesce(p_novo_brinco, v_animal.brinco);
  if v_brinco_destino <= 0 then raise exception 'Informe um brinco válido.'; end if;
  if exists (
    select 1 from public.animais
    where fazenda_id = v_destino.id and brinco = v_brinco_destino
  ) then
    raise exception 'O brinco % já foi utilizado na fazenda de destino, inclusive em animais inativos. Informe outro brinco.', v_brinco_destino;
  end if;

  -- Esta atualização e o histórico pertencem à mesma transação da RPC.
  update public.animais set
    fazenda_id = v_destino.id,
    rebanho_id = p_rebanho_destino_id,
    brinco = v_brinco_destino,
    data_entrada = now(),
    atualizado_em = now()
  where id = v_animal.id and fazenda_id = v_transferencia.fazenda_origem_id;

  update public.transferencias_entre_fazendas set
    status = 'aceita', respondido_em = now(), concluido_em = now(),
    brinco_destino = v_brinco_destino, atualizado_em = now()
  where id = v_transferencia.id;

  insert into public.transferencias_entre_fazendas_historico (
    transferencia_id, evento, autor_id, detalhes
  ) values (
    v_transferencia.id, 'aceita', auth.uid(),
    jsonb_build_object('brinco_destino', v_brinco_destino, 'rebanho_destino_id', p_rebanho_destino_id)
  );
  return v_transferencia.id;
end;
$$;

revoke all on function public.identificar_destino_transferencia(uuid) from public;
grant execute on function public.identificar_destino_transferencia(uuid) to authenticated;
revoke all on function public.solicitar_transferencia_entre_fazendas(uuid, uuid, text) from public;
grant execute on function public.solicitar_transferencia_entre_fazendas(uuid, uuid, text) to authenticated;
revoke all on function public.responder_transferencia_entre_fazendas(uuid, boolean, uuid, integer) from public;
grant execute on function public.responder_transferencia_entre_fazendas(uuid, boolean, uuid, integer) to authenticated;
