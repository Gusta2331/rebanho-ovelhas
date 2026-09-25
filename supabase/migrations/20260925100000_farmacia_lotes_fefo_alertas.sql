-- Evolução da Farmácia: estoque preciso, lotes, FEFO e alertas.
-- Compatível com os dados já existentes.

alter table public.farmacia_produtos
  add column if not exists fabricante text,
  add column if not exists conteudo_embalagem numeric(12,3),
  add column if not exists unidade_embalagem text,
  add column if not exists unidade_estoque text;

update public.farmacia_produtos
set unidade_estoque = coalesce(nullif(unidade_estoque, ''), unidade)
where unidade_estoque is null or unidade_estoque = '';

create table if not exists public.farmacia_lotes (
  id uuid primary key default gen_random_uuid(),
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  produto_id uuid not null references public.farmacia_produtos(id) on delete cascade,
  codigo_lote text,
  quantidade_inicial numeric(12,3) not null default 0 check (quantidade_inicial >= 0),
  quantidade_atual numeric(12,3) not null default 0 check (quantidade_atual >= 0),
  validade date,
  fabricante text,
  observacoes text,
  created_at timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists farmacia_lotes_produto_idx
  on public.farmacia_lotes(produto_id, validade, created_at);
create index if not exists farmacia_lotes_fazenda_idx
  on public.farmacia_lotes(fazenda_id);

alter table public.farmacia_movimentacoes
  add column if not exists farmacia_lote_id uuid
    references public.farmacia_lotes(id) on delete set null,
  add column if not exists movimentacao_grupo_id uuid;

create index if not exists farmacia_movimentacoes_lote_idx
  on public.farmacia_movimentacoes(farmacia_lote_id);
create index if not exists farmacia_movimentacoes_grupo_idx
  on public.farmacia_movimentacoes(movimentacao_grupo_id);

drop index if exists public.farmacia_movimentacoes_manejo_uidx;
create unique index if not exists farmacia_movimentacoes_manejo_lote_uidx
  on public.farmacia_movimentacoes(manejo_id, farmacia_lote_id)
  where manejo_id is not null and farmacia_lote_id is not null;

do $$
declare
  p record;
begin
  for p in
    select id, fazenda_id, estoque, validade, fabricante
    from public.farmacia_produtos
    where estoque > 0
  loop
    if not exists (
      select 1 from public.farmacia_lotes l where l.produto_id = p.id
    ) then
      insert into public.farmacia_lotes (
        fazenda_id, produto_id, codigo_lote, quantidade_inicial,
        quantidade_atual, validade, fabricante, observacoes
      ) values (
        p.fazenda_id, p.id, 'ESTOQUE-INICIAL', p.estoque,
        p.estoque, p.validade, p.fabricante,
        'Lote criado automaticamente na migração do estoque existente.'
      );
    end if;
  end loop;
end $$;

create table if not exists public.farmacia_alertas (
  id uuid primary key default gen_random_uuid(),
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  produto_id uuid not null references public.farmacia_produtos(id) on delete cascade,
  tipo text not null check (tipo in ('estoque_baixo','validade_proxima','produto_vencido')),
  titulo text not null,
  mensagem text not null,
  chave text not null,
  aberto boolean not null default true,
  created_at timestamptz not null default now(),
  resolvido_em timestamptz,
  unique (fazenda_id, produto_id, tipo, chave)
);

create index if not exists farmacia_alertas_abertos_idx
  on public.farmacia_alertas(fazenda_id, aberto, created_at desc);

create table if not exists public.notificacao_dispositivos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fazenda_id uuid not null references public.fazendas(id) on delete cascade,
  fcm_token text not null,
  plataforma text not null default 'android',
  ativo boolean not null default true,
  ultimo_acesso timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (fcm_token)
);

create index if not exists notificacao_dispositivos_usuario_idx
  on public.notificacao_dispositivos(user_id, fazenda_id, ativo);

alter table public.farmacia_lotes enable row level security;
alter table public.farmacia_alertas enable row level security;
alter table public.notificacao_dispositivos enable row level security;

drop policy if exists "farmacia_lotes_select" on public.farmacia_lotes;
create policy "farmacia_lotes_select" on public.farmacia_lotes
for select to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = farmacia_lotes.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "farmacia_lotes_insert" on public.farmacia_lotes;
create policy "farmacia_lotes_insert" on public.farmacia_lotes
for insert to authenticated
with check (exists (
  select 1 from public.fazendas f
  where f.id = farmacia_lotes.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "farmacia_lotes_update" on public.farmacia_lotes;
create policy "farmacia_lotes_update" on public.farmacia_lotes
for update to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = farmacia_lotes.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
))
with check (exists (
  select 1 from public.fazendas f
  where f.id = farmacia_lotes.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "farmacia_alertas_select" on public.farmacia_alertas;
create policy "farmacia_alertas_select" on public.farmacia_alertas
for select to authenticated
using (exists (
  select 1 from public.fazendas f
  where f.id = farmacia_alertas.fazenda_id
    and f.proprietario_id = auth.uid()
    and f.ativo = true
));

drop policy if exists "notificacao_dispositivos_select" on public.notificacao_dispositivos;
create policy "notificacao_dispositivos_select" on public.notificacao_dispositivos
for select to authenticated using (user_id = auth.uid());

drop policy if exists "notificacao_dispositivos_insert" on public.notificacao_dispositivos;
create policy "notificacao_dispositivos_insert" on public.notificacao_dispositivos
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.fazendas f
    where f.id = notificacao_dispositivos.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
);

drop policy if exists "notificacao_dispositivos_update" on public.notificacao_dispositivos;
create policy "notificacao_dispositivos_update" on public.notificacao_dispositivos
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.farmacia_atualizar_alerta_estoque()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estoque <= new.estoque_minimo and old.estoque > old.estoque_minimo then
    insert into public.farmacia_alertas (
      fazenda_id, produto_id, tipo, titulo, mensagem, chave, aberto
    ) values (
      new.fazenda_id, new.id, 'estoque_baixo', 'Estoque baixo',
      'O produto "' || new.nome || '" atingiu o estoque mínimo (' ||
        trim(to_char(new.estoque_minimo, 'FM999999990.###')) || ' ' ||
        coalesce(new.unidade_estoque, new.unidade) || ').',
      'estoque-minimo', true
    )
    on conflict (fazenda_id, produto_id, tipo, chave)
    do update set aberto = true, resolvido_em = null, created_at = now(),
      titulo = excluded.titulo, mensagem = excluded.mensagem;
  elsif new.estoque > new.estoque_minimo and old.estoque <= old.estoque_minimo then
    update public.farmacia_alertas
       set aberto = false, resolvido_em = now()
     where fazenda_id = new.fazenda_id and produto_id = new.id
       and tipo = 'estoque_baixo' and chave = 'estoque-minimo' and aberto = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_farmacia_alerta_estoque on public.farmacia_produtos;
create trigger trg_farmacia_alerta_estoque
after update of estoque, estoque_minimo on public.farmacia_produtos
for each row execute function public.farmacia_atualizar_alerta_estoque();

create or replace function public.farmacia_consumir_fefo(
  p_fazenda_id uuid, p_produto_id uuid, p_quantidade numeric, p_data date,
  p_lote_id uuid default null, p_animal_id uuid default null,
  p_manejo_id uuid default null, p_movimentacao_grupo_id uuid default null,
  p_observacoes text default null, p_movimentacao_id uuid default null
)
returns numeric
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_restante numeric(12,3) := p_quantidade;
  v_consumir numeric(12,3);
  v_lote public.farmacia_lotes%rowtype;
  v_estoque numeric(12,3);
begin
  if p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Informe uma quantidade maior que zero.';
  end if;

  if not exists (
    select 1 from public.fazendas f
    where f.id = p_fazenda_id and f.proprietario_id = auth.uid() and f.ativo = true
  ) then raise exception 'Fazenda não autorizada.'; end if;

  if not exists (
    select 1 from public.farmacia_produtos p
    where p.id = p_produto_id and p.fazenda_id = p_fazenda_id and p.ativo = true
  ) then raise exception 'Produto não encontrado.'; end if;

  if p_lote_id is not null then
    select * into v_lote
    from public.farmacia_lotes
    where id = p_lote_id and produto_id = p_produto_id
      and fazenda_id = p_fazenda_id and quantidade_atual >= p_quantidade
    for update;
    if not found then raise exception 'Lote selecionado não possui estoque suficiente.'; end if;

    update public.farmacia_lotes
       set quantidade_atual = quantidade_atual - p_quantidade, atualizado_em = now()
     where id = v_lote.id;

    insert into public.farmacia_movimentacoes (
      id, fazenda_id, produto_id, tipo, quantidade, data, lote_id, animal_id,
      manejo_id, observacoes, farmacia_lote_id, movimentacao_grupo_id
    ) values (
      coalesce(p_movimentacao_id, gen_random_uuid()), p_fazenda_id, p_produto_id,
      'saida', p_quantidade, p_data,
      (select rebanho_id from public.animais where id = p_animal_id),
      p_animal_id, p_manejo_id, p_observacoes, p_lote_id, p_movimentacao_grupo_id
    );
    v_restante := 0;
  else
    for v_lote in
      select * from public.farmacia_lotes
      where produto_id = p_produto_id and fazenda_id = p_fazenda_id
        and quantidade_atual > 0
      order by case when validade is null then 1 else 0 end,
               validade asc, created_at asc, id asc
      for update
    loop
      exit when v_restante <= 0;
      v_consumir := least(v_lote.quantidade_atual, v_restante);

      update public.farmacia_lotes
         set quantidade_atual = quantidade_atual - v_consumir, atualizado_em = now()
       where id = v_lote.id;

      insert into public.farmacia_movimentacoes (
        id, fazenda_id, produto_id, tipo, quantidade, data, lote_id, animal_id,
        manejo_id, observacoes, farmacia_lote_id, movimentacao_grupo_id
      ) values (
        case when p_movimentacao_id is not null and v_restante = p_quantidade
          then p_movimentacao_id else gen_random_uuid() end,
        p_fazenda_id, p_produto_id, 'saida', v_consumir, p_data,
        (select rebanho_id from public.animais where id = p_animal_id),
        p_animal_id, p_manejo_id, p_observacoes, v_lote.id, p_movimentacao_grupo_id
      );
      v_restante := v_restante - v_consumir;
    end loop;
  end if;

  if v_restante > 0 then raise exception 'Estoque insuficiente.'; end if;

  select coalesce(sum(quantidade_atual), 0) into v_estoque
  from public.farmacia_lotes
  where produto_id = p_produto_id and fazenda_id = p_fazenda_id;

  update public.farmacia_produtos
     set estoque = v_estoque, atualizado_em = now()
   where id = p_produto_id and fazenda_id = p_fazenda_id;

  return p_quantidade;
end;
$$;

create or replace function public.registrar_movimentacao_farmacia(
  p_id uuid, p_fazenda_id uuid, p_produto_id uuid, p_tipo text,
  p_quantidade numeric, p_data date, p_lote_id uuid default null,
  p_animal_id uuid default null, p_observacoes text default null,
  p_codigo_lote text default null, p_validade date default null,
  p_fabricante text default null, p_farmacia_lote_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_existente jsonb;
  v_lote uuid;
  v_estoque numeric;
begin
  select to_jsonb(m) into v_existente
  from public.farmacia_movimentacoes m where m.id = p_id;
  if v_existente is not null then return v_existente; end if;

  if p_tipo = 'entrada' then
    v_lote := p_farmacia_lote_id;
    if v_lote is null then
      insert into public.farmacia_lotes (
        fazenda_id, produto_id, codigo_lote, quantidade_inicial,
        quantidade_atual, validade, fabricante
      ) values (
        p_fazenda_id, p_produto_id, nullif(trim(p_codigo_lote), ''),
        p_quantidade, p_quantidade, p_validade, nullif(trim(p_fabricante), '')
      ) returning id into v_lote;
    else
      update public.farmacia_lotes
         set quantidade_atual = quantidade_atual + p_quantidade,
             quantidade_inicial = quantidade_inicial + p_quantidade,
             atualizado_em = now()
       where id = v_lote and produto_id = p_produto_id and fazenda_id = p_fazenda_id;
      if not found then raise exception 'Lote de farmácia não encontrado.'; end if;
    end if;

    insert into public.farmacia_movimentacoes (
      id, fazenda_id, produto_id, tipo, quantidade, data, lote_id, animal_id,
      observacoes, farmacia_lote_id
    ) values (
      p_id, p_fazenda_id, p_produto_id, 'entrada', p_quantidade, p_data,
      p_lote_id, p_animal_id, p_observacoes, v_lote
    );

    select coalesce(sum(quantidade_atual), 0) into v_estoque
    from public.farmacia_lotes where produto_id = p_produto_id and fazenda_id = p_fazenda_id;
    update public.farmacia_produtos set estoque = v_estoque, atualizado_em = now()
    where id = p_produto_id and fazenda_id = p_fazenda_id;
  elsif p_tipo = 'saida' then
    perform public.farmacia_consumir_fefo(
      p_fazenda_id, p_produto_id, p_quantidade, p_data, p_farmacia_lote_id,
      p_animal_id, null, gen_random_uuid(), p_observacoes, p_id
    );
  else
    raise exception 'Tipo de movimentação inválido.';
  end if;

  select to_jsonb(m) into v_existente
  from public.farmacia_movimentacoes m where m.id = p_id;
  return v_existente;
end;
$$;

grant execute on function public.farmacia_consumir_fefo(uuid, uuid, numeric, date, uuid, uuid, uuid, uuid, text, uuid) to authenticated;
grant execute on function public.registrar_movimentacao_farmacia(uuid, uuid, uuid, text, numeric, date, uuid, uuid, text, text, date, text, uuid) to authenticated;
