-- Novas faixas comerciais do OviGestão.
-- Mantém IDs antigos para preservar pagamentos históricos, mas migra atribuições atuais
-- para faixas equivalentes antes de ocultar os planos antigos do catálogo.
-- Preço: R$ 9,99 até 50 animais; acréscimo de R$ 5,00 a cada faixa adicional de 50.
-- Não cria promoções nem altera validade de planos já atribuídos.

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

-- Reassocia os planos atuais à nova faixa equivalente, preservando validade e status.
update public.planos_fazenda pf
set plano_id = 'faixa_' || substring(pp.id from '^ate_(\\d+)$'),
    atualizado_em = now()
from public.planos_produtor pp
where pp.id = pf.plano_id
  and pp.id ~ '^ate_(100|200|300|400|500|600|700|800|900|1000)$';

update public.planos_pendentes_produtor p
set plano_id = 'faixa_' || substring(pp.id from '^ate_(\\d+)$'),
    atualizado_em = now()
from public.planos_produtor pp
where pp.id = p.plano_id
  and pp.id ~ '^ate_(100|200|300|400|500|600|700|800|900|1000)$';

-- IDs antigos continuam no banco para preservar referências em pagamentos/histórico,
-- mas deixam de ser oferecidos para novas contratações.
update public.planos_produtor
set ativo = false
where id in (
  'ate_100', 'ate_200', 'ate_300', 'ate_400', 'ate_500',
  'ate_600', 'ate_700', 'ate_800', 'ate_900', 'ate_1000'
);

-- Rebanhos acima de 1.000 animais continuam sob consulta.
update public.planos_produtor
set nome = 'Plano personalizado (mais de 1.000 animais)',
    limite_animais = null,
    preco_mensal = null,
    ativo = true
where id = 'personalizado';

notify pgrst, 'reload schema';
