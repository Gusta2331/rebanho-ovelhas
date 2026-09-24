-- Corrige a atualização da reprodução quando uma nova monta é registrada.
-- O PostgreSQL aplica WITH CHECK em UPDATE, por isso apenas a política de INSERT
-- não é suficiente para mudar o status/datas da reprodução após a cobertura.

drop policy if exists "reproducoes_update_proprietario" on public.reproducoes;

create policy "reproducoes_update_proprietario"
on public.reproducoes
for update
to authenticated
using (
  exists (
    select 1
    from public.fazendas f
    where f.id = reproducoes.fazenda_id
      and f.proprietario_id = auth.uid()
      and f.ativo = true
  )
)
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
