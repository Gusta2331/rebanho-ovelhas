import { createClient } from 'npm:@supabase/supabase-js@2'
import { cert, getApps, initializeApp } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

type PlanoVencimento = {
  fazenda_id: string
  plano_id: string
  validade_em: string
  fazendas: { proprietario_id: string; nome: string; ativo: boolean }
  planos_produtor: { nome: string } | null
}

function firebaseApp() {
  const existing = getApps()
  if (existing.length > 0) return existing[0]

  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON não configurado.')

  return initializeApp({ credential: cert(JSON.parse(raw)) })
}

function json(body: unknown, status = 200) {
  return Response.json(body, { status })
}

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 })
    }

    const serviceKey = Deno.env.get('OVIGESTAO_SERVICE_ROLE_KEY')
    if (!serviceKey) throw new Error('OVIGESTAO_SERVICE_ROLE_KEY não configurado.')

    if (request.headers.get('apikey') !== serviceKey) {
      return json({ ok: false, error: 'Não autorizado.' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    if (!supabaseUrl) throw new Error('SUPABASE_URL não configurado.')

    const supabase = createClient(supabaseUrl, serviceKey)
    const agora = new Date()
    // A rotina roda diariamente. A janela de 24 a 48 horas encontra planos
    // prestes a vencer sem depender do minuto exato da validade.
    const inicio = new Date(agora.getTime() + 24 * 60 * 60 * 1000).toISOString()
    const fim = new Date(agora.getTime() + 48 * 60 * 60 * 1000).toISOString()

    const { data: planos, error: planosError } = await supabase
      .from('planos_fazenda')
      .select('fazenda_id, plano_id, validade_em, fazendas!inner(proprietario_id,nome,ativo), planos_produtor(nome)')
      .eq('status', 'ativo')
      .eq('fazendas.ativo', true)
      .gte('validade_em', inicio)
      .lte('validade_em', fim)

    if (planosError) throw planosError

    firebaseApp()

    let verificados = 0
    let enviados = 0
    let duplicados = 0
    let semDispositivo = 0
    let falhas = 0

    for (const plano of (planos ?? []) as unknown as PlanoVencimento[]) {
      verificados++

      const { data: devices, error: devicesError } = await supabase
        .from('notificacao_dispositivos')
        .select('id,fcm_token')
        .eq('fazenda_id', plano.fazenda_id)
        .eq('user_id', plano.fazendas.proprietario_id)
        .eq('ativo', true)

      if (devicesError) {
        console.error('Falha ao consultar dispositivos', plano.fazenda_id, devicesError)
        falhas++
        continue
      }

      if (!devices?.length) {
        semDispositivo++
        continue
      }

      const { data: reserva, error: reservaError } = await supabase
        .from('notificacoes_planos_enviadas')
        .insert({
          fazenda_id: plano.fazenda_id,
          validade_em: plano.validade_em,
          tipo: 'vencimento_plano',
          status: 'processando',
          tentativas: 1,
        })
        .select('id')
        .maybeSingle()

      let reservaId: string | null = reserva?.id ?? null

      if (reservaError?.code === '23505') {
        const { data: existente, error: existenteError } = await supabase
          .from('notificacoes_planos_enviadas')
          .select('id,status,tentativas,atualizado_em')
          .eq('fazenda_id', plano.fazenda_id)
          .eq('validade_em', plano.validade_em)
          .eq('tipo', 'vencimento_plano')
          .maybeSingle()

        if (existenteError || !existente || existente.status === 'enviado') {
          duplicados++
          continue
        }

        const atualizado = new Date(existente.atualizado_em).getTime()
        const travadoHaMaisDe15Min = Date.now() - atualizado > 15 * 60 * 1000
        if (existente.status !== 'erro' && !travadoHaMaisDe15Min) {
          duplicados++
          continue
        }

        const { data: retomada, error: retomadaError } = await supabase
          .from('notificacoes_planos_enviadas')
          .update({
            status: 'processando',
            tentativas: Number(existente.tentativas ?? 1) + 1,
            erro: null,
            atualizado_em: new Date().toISOString(),
          })
          .eq('id', existente.id)
          .neq('status', 'enviado')
          .select('id')
          .maybeSingle()

        if (retomadaError || !retomada) {
          duplicados++
          continue
        }
        reservaId = retomada.id
      }

      if (reservaError && reservaError.code !== '23505') {
        console.error('Falha ao reservar aviso de vencimento', plano.fazenda_id, reservaError)
        falhas++
        continue
      }

      if (!reservaId) {
        falhas++
        continue
      }

      try {
        const resultado = await enviarParaDispositivos(supabase, plano, devices, reservaId)
        enviados += resultado.enviados
        if (resultado.falhas > 0) falhas++
      } catch (error) {
        console.error('Falha ao enviar aviso de vencimento', plano.fazenda_id, error)
        falhas++
      }
    }

    return json({ ok: true, verificados, enviados, duplicados, semDispositivo, falhas })
  } catch (error) {
    console.error('planos-alerta-vencimento:', error)
    return json({ ok: false, error: String(error) }, 500)
  }
})

async function enviarParaDispositivos(
  supabase: ReturnType<typeof createClient>,
  plano: PlanoVencimento,
  devices: { id: string; fcm_token: string }[],
  reservaId: string,
) {
  const dataFormatada = new Intl.DateTimeFormat('pt-BR', {
    timeZone: 'America/Bahia',
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(plano.validade_em))

  let enviados = 0
  let falhas = 0

  for (const device of devices) {
    try {
      await getMessaging().send({
        token: device.fcm_token,
        notification: {
          title: 'Seu plano está perto de vencer',
          body: `O plano ${plano.planos_produtor?.nome ?? 'contratado'} vence em breve (até ${dataFormatada}). Renove para continuar usando todos os recursos.`,
        },
        data: {
          tipo: 'vencimento_plano',
          fazenda_id: plano.fazenda_id,
          validade_em: plano.validade_em,
        },
        android: { priority: 'high' },
      })
      enviados++
    } catch (error) {
      falhas++
      console.error('Falha ao enviar para token', device.id, error)
    }
  }

  const { error: updateError } = await supabase
    .from('notificacoes_planos_enviadas')
    .update({
      status: enviados > 0 ? 'enviado' : 'erro',
      enviados,
      erro: falhas > 0 ? `${falhas} dispositivo(s) não receberam o aviso.` : null,
      enviado_em: enviados > 0 ? new Date().toISOString() : null,
      atualizado_em: new Date().toISOString(),
    })
    .eq('id', reservaId)

  if (updateError) throw updateError
  return { enviados, falhas }
}
