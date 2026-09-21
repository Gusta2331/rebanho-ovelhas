import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../models/manejo.dart';
import '../services/manejo_programado_service.dart';

class ManejoAgendaPage extends StatefulWidget {
  const ManejoAgendaPage({super.key});
  @override State<ManejoAgendaPage> createState() => _ManejoAgendaPageState();
}

class _ManejoAgendaPageState extends State<ManejoAgendaPage> {
  final _service = ManejoProgramadoService();
  List<Map<String,dynamic>> _itens = [];
  bool _carregando = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final dados = await _service.getProgramados();
      if (mounted) setState(() { _itens = dados; _carregando = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        _msg(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _tipo(String? valor) {
    switch (Manejo.tipoFromString(valor)) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
      case TipoManejo.outro: return 'Outro';
    }
  }

  IconData _icone(String? valor) {
    switch (Manejo.tipoFromString(valor)) {
      case TipoManejo.vacinacao: return Icons.vaccines_outlined;
      case TipoManejo.vermifugacao: return Icons.medication_outlined;
      case TipoManejo.tratamento: return Icons.medical_services_outlined;
      case TipoManejo.tosquia: return Icons.content_cut_outlined;
      case TipoManejo.pesagem: return Icons.monitor_weight_outlined;
      case TipoManejo.famacha: return Icons.visibility_outlined;
      case TipoManejo.outro: return Icons.assignment_outlined;
    }
  }

  DateTime _data(Map<String,dynamic> item) =>
      DateTime.tryParse(item['data_programada']?.toString() ?? '') ?? DateTime.now();

  String _dataTexto(DateTime d) =>
      d.day.toString().padLeft(2,'0') + '/' + d.month.toString().padLeft(2,'0') + '/' + d.year.toString();

  String _status(Map<String,dynamic> item) {
    if (item['concluido'] == true) return 'Realizado';
    final hoje = DateTime.now();
    final d = _data(item);
    final a = DateTime(hoje.year,hoje.month,hoje.day);
    final b = DateTime(d.year,d.month,d.day);
    if (b.isBefore(a)) return 'Atrasado';
    if (b == a) return 'Hoje';
    return 'Programado';
  }

  Color _cor(String s) {
    if (s == 'Atrasado') return Colors.red;
    if (s == 'Hoje') return Colors.orange;
    if (s == 'Realizado') return Colors.green;
    return AppTheme.primaryColor;
  }

  String _animais(Map<String,dynamic> item) {
    final lista = item['manejos_programados_animais'];
    if (lista is! List || lista.isEmpty) return 'Nenhum animal';
    final nomes = lista.map((x) {
      final a = x is Map ? x['animais'] : null;
      if (a is! Map) return 'Animal';
      final b = a['brinco']?.toString() ?? '';
      final n = a['nome']?.toString().trim();
      return n != null && n.isNotEmpty ? b + ' • ' + n : 'Brinco ' + b;
    }).toList();
    return nomes.length <= 3 ? nomes.join(', ') : nomes.take(3).join(', ') + ' + ' + (nomes.length - 3).toString() + ' outros';
  }

  void _msg(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _novo() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManejoAgendaFormPage()));
    if (ok == true && mounted) _carregar();
  }

  Future<void> _concluir(Map<String,dynamic> item) async {
    try {
      await _service.concluir(item['id'].toString());
      if (mounted) { _msg('Manejo marcado como realizado.'); _carregar(); }
    } catch(e) { _msg(e.toString().replaceFirst('Exception: ','')); }
  }

  Future<void> _reprogramar(Map<String,dynamic> item) async {
    final d = await showDatePicker(
      context: context, initialDate: _data(item).isBefore(DateTime.now()) ? DateTime.now() : _data(item),
      firstDate: DateTime.now(), lastDate: DateTime(2100), locale: const Locale('pt','BR'),
    );
    if (d == null) return;
    try { await _service.reprogramar(item['id'].toString(), d); if(mounted){_msg('Manejo reprogramado.');_carregar();} }
    catch(e){_msg(e.toString().replaceFirst('Exception: ',''));}
  }

  Future<void> _excluir(Map<String,dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir programação'),
        content: const Text('Deseja excluir este manejo programado?'),
        actions: [
          TextButton(onPressed:()=>Navigator.of(c).pop(false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.of(c).pop(true),child:const Text('Excluir')),
        ],
      ),
    );
    if(ok != true) return;
    try { await _service.excluir(item['id'].toString()); if(mounted){_msg('Programação excluída.');_carregar();} }
    catch(e){_msg(e.toString().replaceFirst('Exception: ',''));}
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda de manejo')),
      body: RefreshIndicator(onRefresh:_carregar,child:_body()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:_carregando ? null : _novo, backgroundColor:AppTheme.primaryColor,
        foregroundColor:Colors.white, icon:const Icon(Icons.add), label:const Text('Programar manejo')),
    );
  }

  Widget _body() {
    if(_carregando) return const Center(child:CircularProgressIndicator(color:AppTheme.primaryColor));
    if(_itens.isEmpty) return ListView(
      physics:const AlwaysScrollableScrollPhysics(), padding:const EdgeInsets.all(24),
      children:const [
        SizedBox(height:80), Icon(Icons.event_note_outlined,size:64), SizedBox(height:16),
        Center(child:Text('Nenhum manejo programado.',style:TextStyle(fontSize:17,fontWeight:FontWeight.w600))),
        SizedBox(height:8), Center(child:Text('Programe cuidados para uma ou várias ovelhas.',textAlign:TextAlign.center)),
      ]);
    return ListView.separated(
      physics:const AlwaysScrollableScrollPhysics(), padding:const EdgeInsets.fromLTRB(16,16,16,100),
      itemCount:_itens.length, separatorBuilder:(_,__)=>const SizedBox(height:10),
      itemBuilder:(context,index) {
        final item=_itens[index]; final status=_status(item); final cor=_cor(status);
        return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            CircleAvatar(backgroundColor:AppTheme.primaryColor.withValues(alpha:.10),child:Icon(_icone(item['tipo']?.toString()),color:AppTheme.primaryColor)),
            const SizedBox(width:12), Expanded(child:Text(_tipo(item['tipo']?.toString()),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
            Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:cor.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(status,style:TextStyle(color:cor,fontWeight:FontWeight.w700,fontSize:12))),
          ]),
          const SizedBox(height:12),
          Text('Data: ' + _dataTexto(_data(item))),
          const SizedBox(height:8),
          Text('Animais: ' + _animais(item)),
          if((item['observacoes']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height:8), Text(item['observacoes'].toString(),style:const TextStyle(color:Colors.black54)),
          ],
          const SizedBox(height:12),
          Wrap(spacing:8,children:[
            if(status!='Realizado') FilledButton.icon(onPressed:()=>_concluir(item),icon:const Icon(Icons.check,size:18),label:const Text('Realizar')),
            if(status!='Realizado') OutlinedButton.icon(onPressed:()=>_reprogramar(item),icon:const Icon(Icons.edit_calendar_outlined,size:18),label:const Text('Reprogramar')),
            OutlinedButton.icon(onPressed:()=>_excluir(item),icon:const Icon(Icons.delete_outline,size:18),label:const Text('Excluir')),
          ]),
        ])));
      });
  }
}

class ManejoAgendaFormPage extends StatefulWidget {
  const ManejoAgendaFormPage({super.key});
  @override State<ManejoAgendaFormPage> createState()=>_ManejoAgendaFormPageState();
}

class _ManejoAgendaFormPageState extends State<ManejoAgendaFormPage> {
  final _service=ManejoProgramadoService();
  final _animalService=AnimalService();
  final _observacoes=TextEditingController();
  List<Map<String,dynamic>> _animais=[];
  final Set<String> _selecionados={};
  TipoManejo _tipo=TipoManejo.vacinacao;
  DateTime _data=DateTime.now().add(const Duration(days:1));
  bool _carregando=true; bool _salvando=false;

  @override void initState(){super.initState();_carregar();}
  @override void dispose(){_observacoes.dispose();super.dispose();}

  Future<void> _carregar() async {
    try {
      final a=await _animalService.getAnimaisAtivos();
      if(mounted)setState((){_animais=a;_carregando=false;});
    } catch(e) {
      if(mounted){setState(()=>_carregando=false);_msg(e.toString().replaceFirst('Exception: ',''));}
    }
  }

  String _animal(Map<String,dynamic> a) {
    final b=a['brinco']?.toString() ?? ''; final n=a['nome']?.toString().trim();
    return n!=null && n.isNotEmpty ? b+' • '+n : 'Brinco '+b;
  }

  String _tipoTexto(TipoManejo t) {
    switch(t){
      case TipoManejo.vacinacao:return'Vacinação';
      case TipoManejo.vermifugacao:return'Vermifugação';
      case TipoManejo.tratamento:return'Tratamento';
      case TipoManejo.tosquia:return'Tosquia';
      case TipoManejo.pesagem:return'Pesagem';
      case TipoManejo.famacha:return'FAMACHA';
      case TipoManejo.outro:return'Outro';
    }
  }

  String _dataTexto(DateTime d)=>d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();

  Future<void> _salvar() async {
    if(_selecionados.isEmpty){_msg('Selecione pelo menos um animal.');return;}
    setState(()=>_salvando=true);
    try {
      await _service.criar(tipo:_tipo,dataProgramada:_data,animalIds:_selecionados.toList(),observacoes:_observacoes.text);
      if(mounted)Navigator.of(context).pop(true);
    } catch(e) {
      if(mounted){setState(()=>_salvando=false);_msg(e.toString().replaceFirst('Exception: ',''));}
    }
  }

  Future<void> _dataPicker() async {
    final d=await showDatePicker(context:context,initialDate:_data,firstDate:DateTime.now(),lastDate:DateTime(2100),locale:const Locale('pt','BR'));
    if(d!=null&&mounted)setState(()=>_data=d);
  }

  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override Widget build(BuildContext context){
    final todos=_animais.isNotEmpty&&_animais.every((a)=>_selecionados.contains(a['id']?.toString()));
    return Scaffold(
      appBar:AppBar(title:const Text('Programar manejo')),
      body:_carregando ? const Center(child:CircularProgressIndicator(color:AppTheme.primaryColor)) :
      ListView(padding:const EdgeInsets.fromLTRB(20,20,20,32),children:[
        DropdownButtonFormField<TipoManejo>(value:_tipo,decoration:const InputDecoration(labelText:'Tipo de manejo',prefixIcon:Icon(Icons.category_outlined),border:OutlineInputBorder()),
        items:TipoManejo.values.map((t)=>DropdownMenuItem(value:t,child:Text(_tipoTexto(t)))).toList(),
        onChanged:_salvando?null:(v){if(v!=null)setState(()=>_tipo=v);}),
        const SizedBox(height:16),
        InkWell(onTap:_salvando?null:_dataPicker,child:InputDecorator(decoration:const InputDecoration(labelText:'Data programada',prefixIcon:Icon(Icons.calendar_today_outlined),border:OutlineInputBorder()),child:Text(_dataTexto(_data)))),
        const SizedBox(height:16),
        Container(decoration:BoxDecoration(border:Border.all(color:Colors.black12),borderRadius:BorderRadius.circular(16)),child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,12,8,4),child:Row(children:[
            const Expanded(child:Text('Animais',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
            TextButton(onPressed:_salvando?null:(){setState((){if(todos){_selecionados.clear();}else{_selecionados..clear()..addAll(_animais.map((a)=>a['id'].toString()));}});},child:Text(todos?'Limpar':'Selecionar todas')),
          ])),
          Padding(padding:const EdgeInsets.fromLTRB(16,0,16,8),child:Align(alignment:Alignment.centerLeft,child:Text(_selecionados.length.toString()+' selecionado(s)',style:const TextStyle(color:Colors.black54)))),
          const Divider(height:1),
          ..._animais.map((a){
            final id=a['id']?.toString(); if(id==null)return const SizedBox.shrink();
            return CheckboxListTile(value:_selecionados.contains(id),onChanged:_salvando?null:(v){setState(()=>v==true?_selecionados.add(id):_selecionados.remove(id));},title:Text(_animal(a)),secondary:const Icon(Icons.pets_outlined),controlAffinity:ListTileControlAffinity.leading);
          }),
        ])),
        const SizedBox(height:16),
        TextField(controller:_observacoes,enabled:!_salvando,maxLines:4,decoration:const InputDecoration(labelText:'Observações',alignLabelWithHint:true,prefixIcon:Icon(Icons.notes_outlined),border:OutlineInputBorder())),
        const SizedBox(height:24),
        SizedBox(height:52,child:FilledButton.icon(onPressed:_salvando?null:_salvar,icon:_salvando?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.event_available_outlined),label:Text(_salvando?'Salvando...':'Programar manejo'))),
      ]),
    );
  }
}
