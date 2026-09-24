-- Permite ao proprietário criar reproduções somente dentro da própria fazenda.
-- A política valida também a filiação para impedir referências a animais de outra fazenda.
drop policy if exists "reproducoes_insert_proprietario" on public.reproducoes;

create policy "reproducoes_insert_proprietario"
on public.reproducoes
for insert
to authenticated
with check (
  exists (
    select 1
    from public.fazendas f
    where f.id = reproducoes.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
  and exists (
    select 1
    from public.animais a
    where a.id = reproducoes.mae_id
      and a.fazenda_id = reproducoes.fazenda_id
  )
  and (
    reproducoes.pai_id is null
    or exists (
      select 1
      from public.animais a
      where a.id = reproducoes.pai_id
        and a.fazenda_id = reproducoes.fazenda_id
    )
  )
);
