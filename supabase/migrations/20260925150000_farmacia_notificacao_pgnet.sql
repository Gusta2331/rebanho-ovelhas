create or replace function public.farmacia_disparar_notificacao_alerta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
  v_request_id bigint;
begin
  if tg_op = 'INSERT' then
    if new.aberto is distinct from true then
      return new;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.aberto is distinct from false
       or new.aberto is distinct from true then
      return new;
    end if;
  end if;

  select decrypted_secret
    into v_secret
  from vault.decrypted_secrets
  where name = 'ovigestao_service_role_key'
  limit 1;

  if v_secret is null or v_secret = '' then
    raise warning 'Secret do alerta de farmácia não encontrado no Vault.';
    return new;
  end if;

  select net.http_post(
    url := 'https://ezbfjgozqwzricjwxtba.supabase.co/functions/v1/farmacia-alertas',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_secret
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', 'farmacia_alertas',
      'schema', 'public',
      'record', to_jsonb(new),
      'old_record', case
        when tg_op = 'UPDATE' then to_jsonb(old)
        else null
      end
    ),
    timeout_milliseconds := 5000
  )
  into v_request_id;

  raise log 'Notificação de alerta de farmácia enfileirada no pg_net. request_id=%', v_request_id;

  return new;

exception
  when others then
    raise warning 'Falha ao enfileirar notificação de alerta de farmácia: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_farmacia_notificar_alerta
on public.farmacia_alertas;

create trigger trg_farmacia_notificar_alerta
after insert or update of aberto
on public.farmacia_alertas
for each row
execute function public.farmacia_disparar_notificacao_alerta();
