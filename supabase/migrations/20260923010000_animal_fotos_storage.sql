-- Bucket and ownership policies used by AnimalService photo uploads.
-- Photos are public because the app stores and displays public URLs.

insert into storage.buckets (id, name, public)
values ('animal-fotos', 'animal-fotos', true)
on conflict (id) do update set public = excluded.public;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'animal_fotos_read_own_farm'
  ) then
    create policy animal_fotos_read_own_farm
      on storage.objects for select to authenticated
      using (
        bucket_id = 'animal-fotos'
        and exists (
          select 1 from public.fazendas f
          where f.id::text = (storage.foldername(name))[1]
            and f.proprietario_id = auth.uid()
            and f.ativo = true
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'animal_fotos_insert_own_farm'
  ) then
    create policy animal_fotos_insert_own_farm
      on storage.objects for insert to authenticated
      with check (
        bucket_id = 'animal-fotos'
        and exists (
          select 1 from public.fazendas f
          where f.id::text = (storage.foldername(name))[1]
            and f.proprietario_id = auth.uid()
            and f.ativo = true
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'animal_fotos_update_own_farm'
  ) then
    create policy animal_fotos_update_own_farm
      on storage.objects for update to authenticated
      using (
        bucket_id = 'animal-fotos'
        and exists (
          select 1 from public.fazendas f
          where f.id::text = (storage.foldername(name))[1]
            and f.proprietario_id = auth.uid()
            and f.ativo = true
        )
      )
      with check (
        bucket_id = 'animal-fotos'
        and exists (
          select 1 from public.fazendas f
          where f.id::text = (storage.foldername(name))[1]
            and f.proprietario_id = auth.uid()
            and f.ativo = true
        )
      );
  end if;
end
$$;
