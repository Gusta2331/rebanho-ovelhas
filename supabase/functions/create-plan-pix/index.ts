import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const mercadoPagoToken = Deno.env.get('MERCADOPAGO_ACCESS_TOKEN')

    if (!supabaseUrl || !anonKey || !serviceKey || !mercadoPagoToken) {
      return json({ error: 'A integração de pagamentos ainda não está configurada no servidor.' }, 500)
    }

    const authorization = request.headers.get('Authorization') ?? ''
    const accessToken = authorization.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!accessToken) return json({ error: 'Faça login para gerar uma cobrança.' }, 401)

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user }, error: authError } = await authClient.auth.getUser(accessToken)
    if (authError || !user?.id || !user.email) return json({ error: 'Sessão inválida.' }, 401)

    const payload = await request.json().catch(() => ({}))
    const planId = String(payload.plano_id ?? '').trim()
    if (!planId) return json({ error: 'Selecione um plano.' }, 400)

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: plan, error: planError } = await admin
      .from('planos_produtor')
      .select('id,nome,preco_mensal,ativo')
      .eq('id', planId)
      .eq('ativo', true)
      .maybeSingle()

    if (planError) throw planError
    if (!plan) return json({ error: 'O plano selecionado não existe ou está indisponível.' }, 400)

    const tabela = Number(plan.preco_mensal)
    if (!Number.isFinite(tabela) || tabela <= 0) {
      return json({ error: 'Este plano não possui preço válido para pagamento.' }, 400)
    }

    // Lê a assinatura atual no servidor. O cliente não pode informar preço nem vencimento.
    const { data: farm } = await admin.from('fazendas')
      .select('id')
      .eq('proprietario_id', user.id)
      .eq('ativo', true)
      .limit(1)
      .maybeSingle()

    let atribuicao: { plano_id: string; validade_em: string | null; planos_produtor: unknown } | null = null
    if (farm) {
      const { data, error } = await admin.from('planos_fazenda')
        .select('plano_id,validade_em,planos_produtor(preco_mensal,limite_animais)')
        .eq('fazenda_id', farm.id)
        .maybeSingle()
      if (error) throw error
      atribuicao = data as typeof atribuicao
    } else {
      const { data, error } = await admin.from('planos_pendentes_produtor')
        .select('plano_id,validade_em,planos_produtor(preco_mensal,limite_animais)')
        .eq('usuario_id', user.id)
        .maybeSingle()
      if (error) throw error
      atribuicao = data as typeof atribuicao
    }

    const atualRaw = atribuicao?.planos_produtor
    const atual = Array.isArray(atualRaw) ? atualRaw[0] : atualRaw
    const precoAtual = atual && typeof atual === 'object'
      ? Number((atual as { preco_mensal?: unknown }).preco_mensal)
      : 0
    const validadeAtual = atribuicao?.validade_em ? new Date(atribuicao.validade_em) : null
    const assinaturaAtiva = validadeAtual !== null &&
      Number.isFinite(validadeAtual.getTime()) && validadeAtual.getTime() > Date.now()
    let tipoOperacao: 'contratacao' | 'renovacao' | 'upgrade' = 'contratacao'
    let amount = Math.round(tabela * 100) / 100
    let diasRestantes = 30

    if (atribuicao && assinaturaAtiva && Number.isFinite(precoAtual) && precoAtual > 0) {
      if (atribuicao.plano_id === plan.id) {
        tipoOperacao = 'renovacao'
      } else if (tabela < precoAtual) {
        return json({
          error: 'O downgrade será agendado para o vencimento do plano atual. Essa opção ainda está sendo preparada e nenhuma cobrança foi criada.',
        }, 409)
      } else if (tabela > precoAtual) {
        tipoOperacao = 'upgrade'
        diasRestantes = Math.max(1, Math.ceil((validadeAtual!.getTime() - Date.now()) / 86400000))
        amount = Math.round(((tabela - precoAtual) * diasRestantes / 30) * 100) / 100
      }
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: 'O valor calculado para esta alteração não é válido. Atualize seu plano e tente novamente.' }, 400)
    }

    const { data: payment, error: insertError } = await admin
      .from('pagamentos_planos')
      .insert({
        usuario_id: user.id,
        plano_id: plan.id,
        valor: amount,
        duracao_dias: tipoOperacao === 'upgrade' ? diasRestantes : 30,
        tipo_operacao: tipoOperacao,
        plano_anterior_id: atribuicao?.plano_id ?? null,
        validade_anterior: assinaturaAtiva ? validadeAtual!.toISOString() : null,
        valor_tabela: tabela,
        status: 'criado',
      })
      .select('id')
      .single()

    if (insertError) throw insertError

    const response = await fetch('https://api.mercadopago.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${mercadoPagoToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Idempotency-Key': payment.id,
      },
      body: JSON.stringify({
        type: 'online',
        total_amount: amount.toFixed(2),
        external_reference: payment.id,
        processing_mode: 'automatic',
        transactions: {
          payments: [{
            amount: amount.toFixed(2),
            payment_method: { id: 'pix', type: 'bank_transfer' },
            expiration_time: 'P1D',
          }],
        },
        payer: { email: user.email },
      }),
    })

    const order = await response.json().catch(() => ({}))
    if (!response.ok) {
      await admin.from('pagamentos_planos')
        .update({ status: 'erro', atualizado_em: new Date().toISOString() })
        .eq('id', payment.id)
      console.error('Mercado Pago order error:', response.status, order)
      return json({
        error: 'O Mercado Pago não conseguiu criar a cobrança. Confira as credenciais de teste e os dados do pagador e tente novamente.',
        referencia: payment.id,
      }, 502)
    }

    const transaction = order?.transactions?.payments?.[0]
    const paymentMethod = transaction?.payment_method ?? {}
    const qrCode = paymentMethod.qr_code ?? null
    const qrCodeBase64 = paymentMethod.qr_code_base64 ?? null
    const ticketUrl = paymentMethod.ticket_url ?? null

    // Criar a cobrança/QR Code não é prova de pagamento. A aprovação só
    // acontece na função verify-plan-payment após consulta autenticada ao provedor.
    const { error: updateError } = await admin.from('pagamentos_planos').update({
      provedor_order_id: String(order.id),
      status: 'pendente',
      qr_code: qrCode,
      qr_code_base64: qrCodeBase64,
      ticket_url: ticketUrl,
      atualizado_em: new Date().toISOString(),
    }).eq('id', payment.id)

    if (updateError) {
      console.error('Could not save Mercado Pago order:', updateError)
      return json({ error: 'A cobrança foi criada, mas não conseguimos salvar seus dados. Informe o suporte com a referência da cobrança.', referencia: payment.id }, 500)
    }

    return json({
      pagamento_id: payment.id,
      plano_id: plan.id,
      plano_nome: plan.nome,
      valor: amount,
      status: 'pendente',
      qr_code: qrCode,
      qr_code_base64: qrCodeBase64,
      ticket_url: ticketUrl,
    })
  } catch (error) {
    console.error('create-plan-pix:', error)
    const message = error instanceof Error ? error.message : 'Erro interno.'
    return json({ error: message }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
