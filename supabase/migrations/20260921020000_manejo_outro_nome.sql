alter table public.manejos
add column if not exists outro_nome text;

alter table public.manejos_programados
add column if not exists outro_nome text;
