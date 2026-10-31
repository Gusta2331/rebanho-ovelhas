-- Integra o escore corporal ao manejo e à agenda sem alterar registros antigos.
alter table public.manejos add column if not exists escore_corporal numeric(2,1);
alter table public.manejos drop constraint if exists manejos_tipo_check;
alter table public.manejos add constraint manejos_tipo_check check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','denticao','escore_corporal','outro'));
alter table public.manejos_programados drop constraint if exists manejos_programados_tipo_check;
alter table public.manejos_programados add constraint manejos_programados_tipo_check check (tipo in ('vacinacao','vermifugacao','tratamento','tosquia','pesagem','famacha','denticao','escore_corporal','outro'));
do $$
begin
 if not exists (select 1 from pg_constraint where conname='manejos_escore_corporal_validacao' and conrelid='public.manejos'::regclass) then
  alter table public.manejos add constraint manejos_escore_corporal_validacao check (escore_corporal is null or (escore_corporal >= 1 and escore_corporal <= 5 and escore_corporal * 2 = round(escore_corporal * 2)));
 end if;
end $$;
create index if not exists idx_manejos_escore_corporal on public.manejos (fazenda_id, animal_id, data desc) where tipo='escore_corporal';
