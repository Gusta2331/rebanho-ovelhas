-- Validade opcional dos planos, mantendo compatibilidade com as atribuições existentes.
alter table public.planos_fazenda
  add column if not exists validade_em timestamptz;

alter table public.planos_pendentes_produtor
  add column if not exists validade_em timestamptz;

-- Ao criar uma fazenda, transfere também a validade do plano pendente.
create or replace function public.aplicar_plano_pendente_fazenda()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plano_id text;
  v_validade_em timestamptz;
begin
  select plano_id, validade_em
    into v_plano_id, v_validade_em
  from public.planos_pendentes_produtor
  where usuario_id = new.proprietario_id;

  if v_plano_id is not null then
    insert into public.planos_fazenda (fazenda_id, plano_id, validade_em, status, atualizado_em)
    values (new.id, v_plano_id, v_validade_em, 'ativo', now())
    on conflict (fazenda_id) do update
      set plano_id = excluded.plano_id,
          validade_em = excluded.validade_em,
          status = 'ativo',
          atualizado_em = now();

    delete from public.planos_pendentes_produtor
    where usuario_id = new.proprietario_id;
  end if;
  return new;
end;
$$;

-- Quando um plano pago vence, o limite efetivo passa a ser o do plano gratuito
-- (10 animais). Os animais existentes permanecem no histórico; novos cadastros
-- ficam bloqueados até a conta voltar a estar dentro do limite ou renovar.
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
  v_vencido boolean;
begin
  if new.status is distinct from 'ativo' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'ativo' and old.fazenda_id = new.fazenda_id then return new; end if;
  perform pg_advisory_xact_lock(hashtext(new.fazenda_id::text));

  select
    case
      when pf.validade_em is not null and pf.validade_em <= now() then 10
      else pp.limite_animais
    end,
    pf.status = 'ativo',
    pf.validade_em is not null and pf.validade_em <= now()
  into v_limite, v_ativo, v_vencido
  from public.planos_fazenda pf
  join public.planos_produtor pp on pp.id = pf.plano_id and pp.ativo = true
  where pf.fazenda_id = new.fazenda_id;

  -- Sem plano atribuído, mantém o comportamento legado.
  if not found then return new; end if;
  if not v_ativo then raise exception 'O plano desta fazenda está suspenso.'; end if;
  if v_limite is null then return new; end if;

  select count(*) into v_contagem
  from public.animais
  where fazenda_id = new.fazenda_id
    and status = 'ativo'
    and (tg_op <> 'UPDATE' or id <> new.id);

  if v_contagem >= v_limite then
    if v_vencido then
      raise exception 'O plano venceu. O limite temporário é de 10 animais ativos. Renove o plano para cadastrar mais.';
    end if;
    raise exception 'O plano permite até % animais ativos. Altere o plano para cadastrar mais.', v_limite;
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';
