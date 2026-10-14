import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const resendKey = Deno.env.get('RESEND_API_KEY')
    const fromEmail = Deno.env.get('RESEND_FROM_EMAIL')

    if (!supabaseUrl || !anonKey || !serviceKey || !resendKey || !fromEmail) {
      throw new Error('Configure SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY e RESEND_FROM_EMAIL nos secrets do Supabase.')
    }

    const authorization = request.headers.get('Authorization') ?? ''
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!token) return json({ error: 'Sessão inválida.' }, 401)

    const caller = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user }, error: authError } = await caller.auth.getUser(token)
    if (authError || !user) return json({ error: 'Sessão inválida.' }, 401)

    const payload = await request.json()
    const messageId = String(payload.message_id ?? '')
    if (!/^[0-9a-f-]{36}$/i.test(messageId)) return json({ error: 'Mensagem inválida.' }, 400)

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: message, error: messageError } = await admin
      .from('mensagens_suporte')
      .select('id, usuario_id, tipo, assunto, mensagem, anexos, criado_em, notificacao_enviada_em')
      .eq('id', messageId)
      .maybeSingle()

    if (messageError) throw messageError
    if (!message || message.usuario_id !== user.id) return json({ error: 'Mensagem não encontrada.' }, 404)
    if (message.notificacao_enviada_em) return json({ ok: true, already_sent: true })

    const tipoLabel: Record<string, string> = {
      bug: 'Erro ou problema',
      sugestao: 'Sugestão',
      duvida: 'Dúvida',
      outro: 'Outro assunto',
    }
    const anexos = (message.anexos ?? []) as string[]
    const links: string[] = []
    for (const path of anexos) {
      const { data, error } = await admin.storage.from('support-attachments').createSignedUrl(path, 60 * 60 * 24 * 7)
      if (error) throw error
      links.push(data.signedUrl)
    }

    const dataFormatada = new Intl.DateTimeFormat('pt-BR', {
      timeZone: 'America/Bahia',
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(message.criado_em))

    const texto = [
      'Nova mensagem recebida pelo OviGestão',
      '',
      `Tipo: ${tipoLabel[message.tipo] ?? message.tipo}`,
      `Assunto: ${message.assunto}`,
      `Usuário: ${user.email ?? 'E-mail não informado'}`,
      `ID da conta: ${user.id}`,
      `Data: ${dataFormatada}`,
      '',
      'Mensagem:',
      message.mensagem,
      '',
      anexos.length ? 'Links privados dos anexos (válidos por 7 dias):' : 'Nenhum anexo.',
      ...links,
    ].join('\n')

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: ['ovigestao.app@gmail.com'],
        subject: `[OviGestão] ${tipoLabel[message.tipo] ?? 'Contato'}: ${message.assunto}`,
        text: texto,
        reply_to: user.email ? [user.email] : undefined,
      }),
    })

    if (!emailResponse.ok) {
      const details = await emailResponse.text()
      await admin.from('mensagens_suporte').update({
        notificacao_erro: details.slice(0, 1000),
      }).eq('id', messageId)
      console.error('Falha no Resend:', details)
      return json({ error: 'A mensagem ficou salva, mas o aviso por e-mail falhou.' }, 502)
    }

    await admin.from('mensagens_suporte').update({
      notificacao_enviada_em: new Date().toISOString(),
      notificacao_erro: null,
    }).eq('id', messageId)

    return json({ ok: true })
  } catch (error) {
    console.error('notify-support-message:', error)
    return json({ error: 'Não foi possível enviar a notificação de suporte.' }, 500)
  }
})
