import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasePageUrl,
  });

  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String releasePageUrl;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/Gusta2331/rebanho-ovelhas/releases/latest';
  static const String _apkAssetName = 'app-release.apk';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(minutes: 3),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OviGestao-Android',
      },
    ),
  );

  Future<AppUpdateInfo?> verificarAtualizacao() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await _dio.get<Object?>(_latestReleaseUrl);
      final data = response.data;

      if (data is! Map<String, dynamic>) return null;
      if (data['draft'] == true || data['prerelease'] == true) return null;

      final tag = (data['tag_name'] as String? ?? '').trim();
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty ||
          !_versaoMaisNova(latestVersion, packageInfo.version)) {
        return null;
      }

      final assets = data['assets'];
      if (assets is! List) return null;

      Map<String, dynamic>? apk;
      for (final item in assets) {
        if (item is Map<String, dynamic> &&
            item['name'] == _apkAssetName &&
            item['browser_download_url'] is String) {
          apk = item;
          break;
        }
      }
      if (apk == null) return null;

      return AppUpdateInfo(
        version: latestVersion,
        downloadUrl: apk['browser_download_url'] as String,
        releaseNotes: (data['body'] as String? ?? '').trim(),
        releasePageUrl: data['html_url'] as String? ?? '',
      );
    } on DioException catch (error) {
      // A falha na verificação nunca deve impedir a abertura do aplicativo.
      stderr.writeln('OviGestão: não foi possível verificar atualização: $error');
      return null;
    } catch (error) {
      stderr.writeln('OviGestão: erro ao verificar atualização: $error');
      return null;
    }
  }

  Future<String> baixarAtualizacao(
    AppUpdateInfo update, {
    required void Function(int received, int total) onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final apkPath = '${directory.path}/ovigestao-atualizacao.apk';
    final file = File(apkPath);

    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      update.downloadUrl,
      apkPath,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
        headers: const {'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: onProgress,
      deleteOnError: true,
    );

    if (!await file.exists() || await file.length() < 1024 * 100) {
      if (await file.exists()) await file.delete();
      throw Exception('O arquivo de atualização está incompleto.');
    }

    return apkPath;
  }

  Future<void> instalarAtualizacao(String apkPath) async {
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : 'Não foi possível abrir o instalador do Android.',
      );
    }
  }

  bool _versaoMaisNova(String candidate, String current) {
    final candidateParts = _partesVersao(candidate);
    final currentParts = _partesVersao(current);
    final length = candidateParts.length > currentParts.length
        ? candidateParts.length
        : currentParts.length;

    for (var index = 0; index < length; index++) {
      final candidatePart =
          index < candidateParts.length ? candidateParts[index] : 0;
      final currentPart =
          index < currentParts.length ? currentParts[index] : 0;
      if (candidatePart > currentPart) return true;
      if (candidatePart < currentPart) return false;
    }
    return false;
  }

  List<int> _partesVersao(String version) {
    final normalized = version.split('+').first;
    return normalized
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
