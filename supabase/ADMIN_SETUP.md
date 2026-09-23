# Administração de produtores e planos

O painel administrativo cria usuários pelo Supabase Auth e associa uma faixa de animais. As credenciais privilegiadas são usadas somente pela Edge Function; o aplicativo móvel nunca recebe a `service_role`.

## Ativação

1. Aplique `20260924010000_produtor_plans_admin.sql` ao projeto Supabase depois das migrations já existentes.
2. Publique a Edge Function `admin-producers`.
3. Configure o segredo da função `ADMIN_EMAILS` com o e-mail da conta que poderá abrir o painel. Para mais de um administrador, separe os endereços por vírgula.
4. Atualize o aplicativo. A opção Administração aparece em Mais; o servidor valida o e-mail em cada solicitação.

No computador com o Supabase CLI instalado, a publicação é feita com `supabase functions deploy admin-producers` e `supabase secrets set ADMIN_EMAILS=seu-email@exemplo.com` após entrar e vincular o projeto. Também é possível publicar a função pelo painel do Supabase.

As variáveis `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são fornecidas pelo ambiente das Edge Functions do Supabase. Não copie a chave `service_role` para o app nem a compartilhe.

Os planos iniciais são faixas de até 300, 600, 1.000 e mais de 1.000 animais. A fazenda mantém o comportamento atual até que um plano seja explicitamente atribuído; contas/fazendas antigas não recebem limite automaticamente. Os preços podem ser definidos no painel quando você decidir os valores.

O painel cria contas, mostra fazendas e quantidade de animais ativos, e altera a faixa contratada. Ele ainda não cobra automaticamente. Para cobrança recorrente no Android será necessário definir preços/produtos e integrar o fluxo de pagamentos adequado à distribuição na Play Store.
