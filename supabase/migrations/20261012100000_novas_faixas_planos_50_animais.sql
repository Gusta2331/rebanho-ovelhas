-- Novas faixas comerciais do OviGestão.
-- Mantém os planos antigos no banco para preservar o histórico de assinaturas já atribuídas.
-- Os planos antigos deixam de aparecer para novas contratações; novas faixas usam IDs próprios.
-- Preço: R$ 9,99 até 50 animais, com acréscimo de R$ 5,00 por faixa adicional de 50.

update public.planos_produtor
set ativo = false
where id in (
  'ate_100', 'ate_200', 'ate_300', 'ate_400', 'ate_500',
  'ate_600', 'ate_700', 'ate_800', 'ate_900', 'ate_1000'
);

insert into public.planos_produtor (id, nome, limite_animais, preco_mensal, ativo)
values ('free_10', 'Grátis (até 10 animais)', 10, 0, true)
on conflict (id) do update
set nome = excluded.nome,
    limite_animais = excluded.limite_animais,
    preco_mensal = excluded.preco_mensal,
    ativo = true;

insert into public.planos_produtor (id, nome, limite_animais, preco_mensal, ativo)
select
  'faixa_' || (faixa * 50)::text,
  'Até ' || (faixa * 50)::text || ' animais',
  faixa * 50,
  round((4.99 + (faixa * 5.00))::numeric, 2),
  true
from generate_series(1, 20) as faixa
on conflict (id) do update
set nome = excluded.nome,
    limite_animais = excluded.limite_animais,
    preco_mensal = excluded.preco_mensal,
    ativo = true;

-- Mantém o plano personalizado disponível para rebanhos acima de 1.000 animais.
update public.planos_produtor
set nome = 'Plano personalizado (mais de 1.000 animais)',
    limite_animais = null,
    preco_mensal = null,
    ativo = true
where id = 'personalizado';

notify pgrst, 'reload schema';
