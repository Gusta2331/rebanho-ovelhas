-- Atualiza as faixas comerciais do OviGestão sem remover IDs de planos existentes.
-- Política inicial: gratuito até 10 animais; R$ 10 até 100; acréscimo de R$ 5
-- por cada faixa adicional de 100 animais. Os preços continuam editáveis no painel.
insert into public.planos_produtor (id, nome, limite_animais, preco_mensal, ativo)
values
  ('free_10', 'Plano gratuito (até 10 animais)', 10, 0, true),
  ('ate_100', 'Até 100 animais', 100, 10, true),
  ('ate_200', 'Até 200 animais', 200, 15, true),
  ('ate_300', 'Até 300 animais', 300, 20, true),
  ('ate_400', 'Até 400 animais', 400, 25, true),
  ('ate_500', 'Até 500 animais', 500, 30, true),
  ('ate_600', 'Até 600 animais', 600, 35, true),
  ('ate_700', 'Até 700 animais', 700, 40, true),
  ('ate_800', 'Até 800 animais', 800, 45, true),
  ('ate_900', 'Até 900 animais', 900, 50, true),
  ('ate_1000', 'Até 1.000 animais', 1000, 55, true),
  ('personalizado', 'Plano personalizado (mais de 1.000 animais)', null, null, true)
on conflict (id) do update
set nome = excluded.nome,
    limite_animais = excluded.limite_animais,
    preco_mensal = excluded.preco_mensal,
    ativo = true;

notify pgrst, 'reload schema';
