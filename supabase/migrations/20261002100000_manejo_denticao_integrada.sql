-- Integra dentição ao histórico de manejos e mantém a ficha do animal sincronizada.
alter table public.manejos
  add column if not exists denticao text,
  add column if not exists denticao_data date;

alter table public.manejos_programados
  drop constraint if exists manejos_programados_tipo_check;

alter table public.manejos_programados
  add constraint manejos_programados_tipo_check
  check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','denticao','outro'));

alter table public.manejos
  drop constraint if exists manejos_tipo_check;

alter table public.manejos
  add constraint manejos_tipo_check
  check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','denticao','outro'));

create or replace function public.atualizar_denticao_animal(p_animal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_denticao text;
  v_data date;
  v_observacoes text;
begin
  select m.denticao, m.denticao_data, m.observacoes
    into v_denticao, v_data, v_observacoes
  from public.manejos m
  where m.animal_id = p_animal_id
    and m.tipo = 'denticao'
  order by m.data desc, m.created_at desc
  limit 1;

  update public.animais
  set denticao = nullif(trim(v_denticao), ''),
      denticao_data = v_data,
      denticao_observacoes = case
        when v_observacoes is null or trim(v_observacoes) = '' then null
        else trim(v_observacoes)
      end,
      atualizado_em = now()
  where id = p_animal_id;
end;
$$;

create or replace function public.sincronizar_denticao_manejo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.atualizar_denticao_animal(old.animal_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.animal_id is distinct from new.animal_id then
    perform public.atualizar_denticao_animal(old.animal_id);
  end if;

  if new.tipo = 'denticao' then
    perform public.atualizar_denticao_animal(new.animal_id);
  elsif tg_op = 'UPDATE' then
    perform public.atualizar_denticao_animal(new.animal_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sincronizar_denticao_manejo on public.manejos;

create trigger trg_sincronizar_denticao_manejo
after insert or update or delete on public.manejos
for each row
execute function public.sincronizar_denticao_manejo();

revoke all on function public.atualizar_denticao_animal(uuid) from public;
grant execute on function public.atualizar_denticao_animal(uuid) to authenticated;

revoke all on function public.sincronizar_denticao_manejo() from public;
grant execute on function public.sincronizar_denticao_manejo() to authenticated;
