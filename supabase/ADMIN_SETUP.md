# Administração de produtores e planos

O painel administrativo cria usuários pelo Supabase Auth e associa uma faixa de animais. As credenciais privilegiadas são usadas somente pela Edge Function; o aplicativo móvel nunca recebe a `service_role`.

## Ativação

### Cobranças Pix (fase inicial de testes)

- Configure `MERCADOPAGO_ACCESS_TOKEN` nos secrets das Edge Functions do Supabase com o Access Token de teste do Mercado Pago. Nunca coloque esse token no Flutter nem no GitHub.
- Aplique a migration `20261013100000_pagamentos_planos_mercado_pago.sql` depois das migrations anteriores.
- Publique a função `create-plan-pix` com `supabase functions deploy create-plan-pix`.
- Esta primeira fase cria a cobrança e devolve QR Code/código Pix. Ela ainda não ativa nem renova o plano automaticamente; isso só deve ser ligado depois que a verificação de notificações do Mercado Pago e a confirmação segura do pagamento forem implementadas e testadas.


1. Aplique as migrations existentes do projeto na ordem dos nomes. A tabela de cobranças Pix é criada pela migration `20261013100000_pagamentos_planos_mercado_pago.sql`; confirme que as migrations anteriores já foram aplicadas antes de executar as pendentes.
2. Publique a Edge Function `admin-producers`.
3. Cadastre primeiro no OviGestão a conta que será administradora. Depois configure o segredo da função `ADMIN_EMAILS` com somente o e-mail `ovigestao.app@gmail.com`. Não coloque esse e-mail como uma regra no código do app. Para manter apenas um administrador, não adicione outros endereços.
4. Atualize o aplicativo. A opção Administração aparece em Mais; o servidor valida o e-mail em cada solicitação.

No computador com o Supabase CLI instalado, a publicação é feita com `supabase functions deploy admin-producers` e `supabase secrets set ADMIN_EMAILS=seu-email@exemplo.com` após entrar e vincular o projeto. Também é possível publicar a função pelo painel do Supabase.

As variáveis `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são fornecidas pelo ambiente das Edge Functions do Supabase. Não copie a chave `service_role` para o app nem a compartilhe.

Os planos iniciais são faixas de até 300, 600, 1.000 e mais de 1.000 animais. A fazenda mantém o comportamento atual até que um plano seja explicitamente atribuído; contas/fazendas antigas não recebem limite automaticamente. Os preços podem ser definidos no painel quando você decidir os valores.

O painel cria contas, mostra fazendas e quantidade de animais ativos, altera a faixa contratada e permite definir a duração em dias (padrão de 30 dias para planos pagos). O plano gratuito não vence. Quando um plano pago vence, a validação de novos animais passa a respeitar temporariamente o limite de 10 animais, sem apagar os animais existentes. O painel ainda não cobra automaticamente. Para cobrança recorrente no Android será necessário definir preços/produtos e integrar o fluxo de pagamentos adequado à distribuição na Play Store.
