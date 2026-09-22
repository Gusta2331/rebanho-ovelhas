import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../models/manejo.dart';

class ManejoService {
  SupabaseClient get _client => SupabaseService.client;

  Future<String> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw Exception('Usuário não autenticado.');

    final fazenda = await _client.from('fazendas').select('id')
        .eq('proprietario_id', usuario.id).eq('ativo', true).maybeSingle();
    final id = fazenda?['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> getVacinas() async {
    final fazendaId = await _getMinhaFazendaId();

    const padroes = [
      'Vacina contra clostridioses',
      'Vacina antirrábica',
      'Vacina contra ectima contagioso',
    ];

    for (final nome in padroes) {
      final existente = await _client.from('vacinas').select('id')
          .eq('fazenda_id', fazendaId).eq('nome', nome).maybeSingle();
      if (existente == null) {
        await _client.from('vacinas').insert({
          'id': const Uuid().v4(),
          'fazenda_id': fazendaId,
          'nome': nome,
        });
      }
    }

    final resultado = await _client.from('vacinas')
        .select('id, nome, fabricante, ativo, dose, dose_unidade, peso_referencia_kg, via_aplicacao, carencia_dias, observacoes')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarVacina({
    required String nome,
    String? fabricante,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome da vacina.');

    final resultado = await _client.from('vacinas').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'fabricante': _text(fabricante),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
      'observacoes': _text(observacoes),
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getVermifugos() async {
    final fazendaId = await _getMinhaFazendaId();
    var resultado = await _client.from('vermifugos').select('*')
        .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    if (resultado.isEmpty) {
      const padroes = ['Albendazol', 'Ivermectina', 'Levamisol', 'Moxidectina'];
      for (final nome in padroes) {
        await _client.from('vermifugos').insert({'id': const Uuid().v4(), 'fazenda_id': fazendaId, 'nome': nome, 'principio_ativo': nome});
      }
      resultado = await _client.from('vermifugos').select('*')
          .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    }
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarVermifugo({
    required String nome,
    String? principioAtivo,
    String? concentracao,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome do vermífugo.');

    final resultado = await _client.from('vermifugos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'principio_ativo': _text(principioAtivo),
      'concentracao': _text(concentracao),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getMedicamentos() async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('medicamentos').select('*')
        .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarMedicamento({
    required String nome,
    String? principioAtivo,
    String? concentracao,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome do medicamento.');

    final resultado = await _client.from('medicamentos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'principio_ativo': _text(principioAtivo),
      'concentracao': _text(concentracao),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<double?> getUltimoPeso(String animalId) async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('peso_kg, data')
        .eq('fazenda_id', fazendaId)
        .eq('animal_id', animalId)
        .not('peso_kg', 'is', null)
        .order('data', ascending: false)
        .limit(1)
        .maybeSingle();

    final peso = resultado?['peso_kg'];
    return peso is num ? peso.toDouble() : double.tryParse(peso?.toString() ?? '');
  }

  Future<List<Map<String, dynamic>>> getManejos() async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('*, animais(brinco, nome)')
        .eq('fazenda_id', fazendaId)
        .order('data', ascending: false);
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarManejo({
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    _validarDados(
      tipo: tipo, famachaEscore: famachaEscore, vacinaId: vacinaId,
      vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
      dose: dose, pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
    );

    await _validarAnimal(animalId, fazendaId);

    final resultado = await _client.from('manejos').insert(_dadosManejo(
      fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
      famachaEscore: famachaEscore, observacoes: observacoes,
      vacinaId: vacinaId, vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante, vacinaLote: vacinaLote,
      outroNome: outroNome, pesoKg: pesoKg, dose: dose,
      doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao, validade: validade,
      carenciaDias: carenciaDias, vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome, vermifugoPrincipioAtivo: vermifugoPrincipioAtivo,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
      medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
    )).select('*, animais(brinco, nome)').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> criarManejosEmLote({
    required List<String> animalIds,
    required DateTime data,
    required TipoManejo tipo,
    Map<String, int> famachaPorAnimal = const {},
    Map<String, double> pesoPorAnimal = const {},
    Map<String, double> dosePorAnimal = const {},
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (animalIds.isEmpty) throw Exception('Selecione pelo menos um animal.');

    if (tipo == TipoManejo.famacha) {
      for (final id in animalIds) {
        final escore = famachaPorAnimal[id];
        if (escore == null || escore < 1 || escore > 5) {
          throw Exception('Informe o FAMACHA de todos os animais selecionados.');
        }
      }
    }

    if (tipo == TipoManejo.pesagem) {
      for (final id in animalIds) {
        final peso = pesoPorAnimal[id];
        if (peso == null || peso <= 0) {
          throw Exception('Informe o peso de todos os animais selecionados.');
        }
      }
    }

    _validarDados(
      tipo: tipo, vacinaId: vacinaId, vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante, vacinaLote: vacinaLote,
      outroNome: outroNome, dose: dose, pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
    );

    final animais = await _client.from('animais').select('id')
        .eq('fazenda_id', fazendaId).eq('status', 'ativo').inFilter('id', animalIds);
    final idsValidos = List<Map<String, dynamic>>.from(animais)
        .map((a) => a['id'].toString()).toSet();

    if (idsValidos.length != animalIds.length ||
        animalIds.any((id) => !idsValidos.contains(id))) {
      throw Exception('Um ou mais animais não estão ativos ou não pertencem à fazenda.');
    }

    final dados = animalIds.map((animalId) => _dadosManejo(
      fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
      famachaEscore: tipo == TipoManejo.famacha ? famachaPorAnimal[animalId] : null,
      observacoes: observacoes, vacinaId: vacinaId, vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante, vacinaLote: vacinaLote,
      outroNome: outroNome, pesoKg: pesoPorAnimal[animalId],
      dose: dosePorAnimal[animalId] ?? dose, doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao, validade: validade, carenciaDias: carenciaDias,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      vermifugoPrincipioAtivo: vermifugoPrincipioAtivo, medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome, medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
    )).toList();

    if (tipo == TipoManejo.famacha) {
      final registros = <Map<String, dynamic>>[];
      for (final dadosAnimal in dados) {
        final registro = await _client
            .from('manejos')
            .insert(dadosAnimal)
            .select('*, animais(brinco, nome)')
            .single();

        final escoreSalvo = registro['famacha_escore'];
        if (escoreSalvo == null) {
          throw Exception('O FAMACHA do animal não foi salvo corretamente.');
        }
        registros.add(Map<String, dynamic>.from(registro));
      }
      return registros;
    }

    final resultado = await _client.from('manejos').insert(dados)
        .select('*, animais(brinco, nome)');
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getHistoricoFamacha(String animalId) async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('*, animais(brinco, nome)').eq('fazenda_id', fazendaId)
        .eq('animal_id', animalId).eq('tipo', 'famacha')
        .order('data', ascending: false);
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> getManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('*, animais(brinco, nome)').eq('id', id)
        .eq('fazenda_id', fazendaId).single();
    return Map<String, dynamic>.from(resultado);
  }

  Future<void> atualizarManejo({
    required String id,
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    _validarDados(
      tipo: tipo, famachaEscore: famachaEscore, vacinaId: vacinaId,
      vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
      dose: dose, pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
    );
    await _validarAnimal(animalId, fazendaId);

    await _client.from('manejos').update({
      ..._dadosManejo(
        fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
        famachaEscore: famachaEscore, observacoes: observacoes,
        vacinaId: vacinaId, vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
        vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
        dose: dose, doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
        viaAplicacao: viaAplicacao, validade: validade, carenciaDias: carenciaDias,
        vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
        vermifugoPrincipioAtivo: vermifugoPrincipioAtivo, medicamentoId: medicamentoId,
        medicamentoNome: medicamentoNome, medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
      )..remove('id')..remove('fazenda_id'),
    }).eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> excluirManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    await _client.from('manejos').delete().eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> _validarAnimal(String animalId, String fazendaId) async {
    final animal = await _client.from('animais').select('id')
        .eq('id', animalId).eq('fazenda_id', fazendaId).eq('status', 'ativo')
        .maybeSingle();
    if (animal == null) {
      throw Exception('O animal selecionado não está ativo ou não pertence à fazenda.');
    }
  }

  void _validarDados({
    required TipoManejo tipo,
    int? famachaEscore,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? pesoKg,
    double? dose,
    double? pesoReferenciaKg,
    String? vermifugoId,
    String? vermifugoNome,
    String? medicamentoId,
    String? medicamentoNome,
  }) {
    if (tipo == TipoManejo.pesagem && (pesoKg == null || pesoKg <= 0)) {
      throw Exception('Informe um peso válido em kg.');
    }
    if (dose != null && dose < 0) throw Exception('A dose não pode ser negativa.');
    if (dose != null && (pesoReferenciaKg == null || pesoReferenciaKg <= 0)) {
      throw Exception('Informe o peso de referência da dose.');
    }
    if (tipo == TipoManejo.famacha &&
        (famachaEscore == null || famachaEscore < 1 || famachaEscore > 5)) {
      throw Exception('Informe uma classificação FAMACHA de 1 a 5.');
    }
    if (tipo != TipoManejo.famacha && famachaEscore != null) {
      throw Exception('A classificação FAMACHA só pode ser usada em uma avaliação FAMACHA.');
    }
    if (tipo == TipoManejo.vacinacao &&
        (vacinaId == null && (vacinaNome == null || vacinaNome.trim().isEmpty))) {
      throw Exception('Informe qual vacina foi aplicada.');
    }
    if (tipo == TipoManejo.vermifugacao &&
        (vermifugoId == null && (vermifugoNome == null || vermifugoNome.trim().isEmpty))) {
      throw Exception('Informe qual vermífugo foi aplicado.');
    }
    if (tipo == TipoManejo.tratamento &&
        (medicamentoId == null && (medicamentoNome == null || medicamentoNome.trim().isEmpty))) {
      throw Exception('Informe qual medicamento foi utilizado.');
    }
    if (tipo == TipoManejo.outro &&
        (outroNome == null || outroNome.trim().isEmpty)) {
      throw Exception('Informe o nome do outro manejo.');
    }
    if (tipo != TipoManejo.outro && outroNome != null && outroNome.trim().isNotEmpty) {
      throw Exception('O nome personalizado só pode ser usado em Outro.');
    }
  }

  Map<String, dynamic> _dadosManejo({
    required String fazendaId,
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) {
    return {
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'animal_id': animalId,
      'tipo': Manejo.tipoToString(tipo),
      'data': data.toIso8601String(),
      'famacha_escore': tipo == TipoManejo.famacha ? famachaEscore : null,
      'observacoes': _text(observacoes),
      'vacina_id': tipo == TipoManejo.vacinacao ? vacinaId : null,
      'vacina_nome': tipo == TipoManejo.vacinacao ? _text(vacinaNome) : null,
      'vacina_fabricante': tipo == TipoManejo.vacinacao ? _text(vacinaFabricante) : null,
      'vacina_lote': tipo == TipoManejo.vacinacao ? _text(vacinaLote) : null,
      'outro_nome': tipo == TipoManejo.outro ? _text(outroNome) : null,
      'peso_kg': tipo == TipoManejo.pesagem ? pesoKg : null,
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'validade': validade?.toIso8601String(),
      'carencia_dias': carenciaDias,
      'vermifugo_id': tipo == TipoManejo.vermifugacao ? vermifugoId : null,
      'vermifugo_nome': tipo == TipoManejo.vermifugacao ? _text(vermifugoNome) : null,
      'vermifugo_principio_ativo': tipo == TipoManejo.vermifugacao ? _text(vermifugoPrincipioAtivo) : null,
      'medicamento_id': tipo == TipoManejo.tratamento ? medicamentoId : null,
      'medicamento_nome': tipo == TipoManejo.tratamento ? _text(medicamentoNome) : null,
      'medicamento_principio_ativo': tipo == TipoManejo.tratamento ? _text(medicamentoPrincipioAtivo) : null,
    };
  }

  String? _text(String? value) {
    final texto = value?.trim();
    return texto == null || texto.isEmpty ? null : texto;
  }
}
