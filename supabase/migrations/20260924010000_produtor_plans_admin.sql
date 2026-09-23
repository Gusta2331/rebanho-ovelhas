-- Additive subscription foundation. Existing farms remain unrestricted until
-- an administrator explicitly assigns a plan.
create table if not exists public.planos_produtor (
  id text primary key,
  nome text not null,
  limite_animais integer,
  preco_mensal numeric(10,2),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  constraint planos_produtor_limite_positivo check (limite_animais is null or limite_animais > 0),
  constraint planos_produtor_preco_nao_negativo check (preco_mensal is null or preco_mensal >= 0)
);

insert into public.planos_produtor (id, nome, limite_animais)
values
  ('ate_300', 'Até 300 animais', 300),
  ('ate_600', '301 a 600 animais', 600),
  ('ate_1000', '601 a 1.000 animais', 1000),
  ('personalizado', 'Mais de 1.000 animais', null)
on conflict (id) do nothing;

create table if not exists public.planos_fazenda (
  fazenda_id uuid primary key references public.fazendas(id) on delete cascade,
  plano_id text not null references public.planos_produtor(id),
  status text not null default 'ativo' check (status in ('ativo', 'suspenso', 'cancelado')),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.planos_pendentes_produtor (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  plano_id text not null references public.planos_produtor(id),
  atualizado_em timestamptz not null default now()
);

alter table public.planos_produtor enable row level security;
alter table public.planos_fazenda enable row level security;
alter table public.planos_pendentes_produtor enable row level security;
-- No client policies are added. Plan assignments are managed through the
-- authenticated, server-side admin Edge Function using service-role access.

create or replace function public.aplicar_plano_pendente_fazenda()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plano_id text;
begin
  select plano_id into v_plano_id
  from public.planos_pendentes_produtor
  where usuario_id = new.proprietario_id;

  if v_plano_id is not null then
    insert into public.planos_fazenda (fazenda_id, plano_id)
    values (new.id, v_plano_id)
    on conflict (fazenda_id) do update
      set plano_id = excluded.plano_id, status = 'ativo', atualizado_em = now();
    delete from public.planos_pendentes_produtor
    where usuario_id = new.proprietario_id;
  end if;
  return new;
end;
$$;

drop trigger if exists aplicar_plano_pendente_fazenda on public.fazendas;
create trigger aplicar_plano_pendente_fazenda
after insert on public.fazendas
for each row execute function public.aplicar_plano_pendente_fazenda();

create or replace function public.validar_limite_plano_animais()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limite integer;
  v_ativo boolean;
  v_contagem bigint;
begin
  if new.status is distinct from 'ativo' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'ativo' and old.fazenda_id = new.fazenda_id then return new; end if;
  perform pg_advisory_xact_lock(hashtext(new.fazenda_id::text));

  select pp.limite_animais, pf.status = 'ativo'
  into v_limite, v_ativo
  from public.planos_fazenda pf
  join public.planos_produtor pp on pp.id = pf.plano_id and pp.ativo = true
  where pf.fazenda_id = new.fazenda_id;

  -- No assigned plan means a legacy farm and leaves current behavior unchanged.
  if not found then return new; end if;
  if not v_ativo then raise exception 'O plano desta fazenda está suspenso.'; end if;
  if v_limite is null then return new; end if;

  select count(*) into v_contagem from public.animais
  where fazenda_id = new.fazenda_id and status = 'ativo'
    and (tg_op <> 'UPDATE' or id <> new.id);
  if v_contagem >= v_limite then
    raise exception 'O plano permite até % animais ativos. Altere o plano para cadastrar mais.', v_limite;
  end if;
  return new;
end;
$$;

drop trigger if exists validar_limite_plano_animais on public.animais;
create trigger validar_limite_plano_animais
before insert or update of status, fazenda_id on public.animais
for each row execute function public.validar_limite_plano_animais();

create or replace function public.admin_resumo_fazendas()
returns table (fazenda_id uuid, animais_ativos bigint)
language sql
security definer
set search_path = public
as $$
  select f.id, count(a.id)
  from public.fazendas f
  left join public.animais a on a.fazenda_id = f.id and a.status = 'ativo'
  group by f.id;
$$;
revoke all on function public.admin_resumo_fazendas() from public, anon, authenticated;
grant execute on function public.admin_resumo_fazendas() to service_role;
