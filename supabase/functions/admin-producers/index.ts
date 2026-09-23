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
    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authorization = request.headers.get('Authorization') ?? ''
    const accessToken = authorization.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!accessToken) return json({ error: 'Sessão inválida.' }, 401)
    const caller = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } })
    const { data: { user }, error: authError } = await caller.auth.getUser(accessToken)
    if (authError || !user?.email) return json({ error: 'Sessão inválida.' }, 401)

    const admins = (Deno.env.get('ADMIN_EMAILS') ?? '').split(',').map((email) => email.trim().toLowerCase()).filter(Boolean)
    if (!admins.includes(user.email.toLowerCase())) return json({ error: 'Acesso restrito à administração.' }, 403)

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
    const payload = await request.json()

    if (payload.action === 'list') {
      const [users, farmsResult, plansResult, statsResult] = await Promise.all([
        listUsers(admin),
        admin.from('fazendas').select('id,nome,proprietario_id,ativo'),
        admin.from('planos_produtor').select('id,nome,limite_animais,preco_mensal,ativo').eq('ativo', true).order('limite_animais', { ascending: true, nullsFirst: false }),
        admin.rpc('admin_resumo_fazendas'),
      ])
      if (farmsResult.error) throw farmsResult.error
      if (plansResult.error) throw plansResult.error
      if (statsResult.error) throw statsResult.error
      const farms = farmsResult.data ?? []
      const stats = new Map((statsResult.data ?? []).map((row: { fazenda_id: string; animais_ativos: number }) => [row.fazenda_id, Number(row.animais_ativos)]))
      const producers = users.map((producer) => ({
        id: producer.id,
        email: producer.email,
        nome: producer.user_metadata?.nome ?? '',
        fazendas: farms.filter((farm) => farm.proprietario_id === producer.id).map((farm) => ({
          ...farm,
          animais_ativos: stats.get(farm.id) ?? 0,
          plano: null,
        })),
      }))
      const assignments = await admin.from('planos_fazenda').select('fazenda_id,plano_id,status,planos_produtor(nome,limite_animais,preco_mensal)')
      if (assignments.error) throw assignments.error
      const planByFarm = new Map((assignments.data ?? []).map((item) => [item.fazenda_id, item]))
      for (const producer of producers) for (const farm of producer.fazendas) farm.plano = planByFarm.get(farm.id) ?? null
      return json({ producers, plans: plansResult.data ?? [] })
    }

    if (payload.action === 'create_producer') {
      const email = String(payload.email ?? '').trim().toLowerCase()
      const password = String(payload.password ?? '')
      const nome = String(payload.nome ?? '').trim()
      const planoId = String(payload.plano_id ?? '')
      if (!email || password.length < 8 || !nome || !planoId) return json({ error: 'Informe nome, e-mail, senha com ao menos 8 caracteres e plano.' }, 400)
      const { data: plan, error: planError } = await admin.from('planos_produtor').select('id').eq('id', planoId).eq('ativo', true).maybeSingle()
      if (planError) throw planError
      if (!plan) return json({ error: 'Plano inválido.' }, 400)
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { nome } })
      if (error) throw error
      const { error: assignmentError } = await admin.from('planos_pendentes_produtor').upsert({ usuario_id: data.user.id, plano_id: planoId, atualizado_em: new Date().toISOString() })
      if (assignmentError) throw new Error(`A conta ${email} foi criada, mas o plano inicial não foi associado: ${assignmentError.message}`)
      return json({ id: data.user.id, email: data.user.email })
    }

    if (payload.action === 'set_plan') {
      const userId = String(payload.user_id ?? '')
      const planId = String(payload.plano_id ?? '')
      if (!userId || !planId) return json({ error: 'Selecione produtor e plano.' }, 400)
      const { data: plan, error: planError } = await admin.from('planos_produtor').select('id').eq('id', planId).eq('ativo', true).maybeSingle()
      if (planError) throw planError
      if (!plan) return json({ error: 'Plano inválido.' }, 400)
      const { data: farm, error: farmError } = await admin.from('fazendas').select('id').eq('proprietario_id', userId).eq('ativo', true).maybeSingle()
      if (farmError) throw farmError
      const result = farm
        ? await admin.from('planos_fazenda').upsert({ fazenda_id: farm.id, plano_id: planId, status: 'ativo', atualizado_em: new Date().toISOString() })
        : await admin.from('planos_pendentes_produtor').upsert({ usuario_id: userId, plano_id: planId, atualizado_em: new Date().toISOString() })
      if (result.error) throw result.error
      return json({ success: true })
    }

    if (payload.action === 'set_plan_price') {
      const planId = String(payload.plano_id ?? '')
      const price = Number(payload.preco_mensal)
      if (!planId || !Number.isFinite(price) || price < 0) return json({ error: 'Informe um preço válido.' }, 400)
      const { error } = await admin.from('planos_produtor').update({ preco_mensal: price }).eq('id', planId)
      if (error) throw error
      return json({ success: true })
    }

    return json({ error: 'Ação desconhecida.' }, 400)
  } catch (error) {
    console.error('admin-producers:', error)
    const message = error instanceof Error ? error.message : 'Erro interno.'
    return json({ error: message }, 400)
  }
})

async function listUsers(admin: ReturnType<typeof createClient>) {
  const users = []
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw error
    users.push(...data.users)
    if (data.users.length < 1000) return users
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}
