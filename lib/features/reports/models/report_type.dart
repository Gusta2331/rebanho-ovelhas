enum ReportType {
  rebanho,
  reproducao,
  manejo,
  farmacia,
  financeiro,
  geral,
}

extension ReportTypeX on ReportType {
  String get title => switch (this) {
    ReportType.rebanho => 'Rebanho',
    ReportType.reproducao => 'Reprodução',
    ReportType.manejo => 'Manejo',
    ReportType.farmacia => 'Farmácia',
    ReportType.financeiro => 'Financeiro',
    ReportType.geral => 'Relatório geral',
  };

  String get description => switch (this) {
    ReportType.rebanho => 'Animais, raças, sexo, idade e situação do rebanho.',
    ReportType.reproducao => 'Coberturas, prenhezes, nascimentos e desempenho.',
    ReportType.manejo => 'Vacinações, pesagens, dentição e outros manejos.',
    ReportType.farmacia => 'Estoque, lotes, validade, consumo e alertas.',
    ReportType.financeiro => 'Receitas, despesas, compras, vendas e resultado.',
    ReportType.geral => 'Uma visão completa e resumida da Fazenda Baixinha.',
  };

  String get iconAsset => switch (this) {
    ReportType.rebanho => 'assets/images/icon_animais.png',
    ReportType.reproducao => 'assets/images/icon_reproducao.png',
    ReportType.manejo => 'assets/images/icon_manejo.png',
    ReportType.farmacia => 'assets/images/icon_farmacia.png',
    ReportType.financeiro => 'assets/images/icon_financeiro.png',
    ReportType.geral => 'assets/images/icon_relatorios.png',
  };
}
