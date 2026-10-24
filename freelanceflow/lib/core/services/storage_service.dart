import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_client.dart';

/// Data structure representing a selected file prior to upload
class PickedFileData {
  final String name;
  final Uint8List bytes;
  final int size;
  final String mimeType;

  const PickedFileData({
    required this.name,
    required this.bytes,
    required this.size,
    required this.mimeType,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage =>
      mimeType.startsWith('image/') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.webp');

  bool get isPdf =>
      mimeType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
}

/// Result of an uploaded file to Supabase Storage
class AppAttachment {
  final String id;
  final String name;
  final String url;
  final int size;
  final String mimeType;

  const AppAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.mimeType,
  });

  factory AppAttachment.fromJson(Map<String, dynamic> json) {
    return AppAttachment(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Arquivo',
      url: json['url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'size': size,
      'mime_type': mimeType,
    };
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Buckets sem leitura pública. O app guarda a URL no formato público como
/// identificador estável do arquivo e troca por uma URL assinada ao exibir/abrir.
const privateBuckets = {'chat_attachments'};

/// Validade das URLs assinadas dos buckets privados.
const signedUrlTtl = Duration(hours: 1);

final _storageObjectUrl = RegExp(
  r'/storage/v1/object/(?:public|sign)/([^/]+)/([^?]+)',
);

/// Bucket e caminho do arquivo quando a URL aponta para um bucket privado.
({String bucket, String path})? privateStorageObject(String url) {
  final match = _storageObjectUrl.firstMatch(url);
  if (match == null || !privateBuckets.contains(match.group(1))) return null;
  return (bucket: match.group(1)!, path: Uri.decodeComponent(match.group(2)!));
}

/// Service providing unified, cross-platform file picking and Supabase Storage uploads
class StorageService {
  final SupabaseClient _supabase;
  final ImagePicker _imagePicker = ImagePicker();

  StorageService(this._supabase);

  /// Picks a single file (Document, PDF, Image)
  Future<PickedFileData?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.bytes == null) return null;

      final extension = file.extension?.toLowerCase() ?? '';
      final mime = _guessMimeType(extension);

      return PickedFileData(
        name: file.name,
        bytes: file.bytes!,
        size: file.size,
        mimeType: mime,
      );
    } catch (e) {
      debugPrint('🚨 [StorageService] Erro ao selecionar arquivo: $e');
      return null;
    }
  }

  /// Picks multiple files
  Future<List<PickedFileData>> pickMultipleFiles({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null) return [];

      final list = <PickedFileData>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          final extension = file.extension?.toLowerCase() ?? '';
          list.add(
            PickedFileData(
              name: file.name,
              bytes: file.bytes!,
              size: file.size,
              mimeType: _guessMimeType(extension),
            ),
          );
        }
      }
      return list;
    } catch (e) {
      debugPrint(
        '🚨 [StorageService] Erro ao selecionar múltiplos arquivos: $e',
      );
      return [];
    }
  }

  /// Picks an image from camera or gallery
  Future<PickedFileData?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
  }) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: imageQuality,
      );
      if (xFile == null) return null;

      final bytes = await xFile.readAsBytes();
      final name = xFile.name;
      final extension = name.split('.').last.toLowerCase();

      return PickedFileData(
        name: name,
        bytes: bytes,
        size: bytes.length,
        mimeType: _guessMimeType(extension),
      );
    } catch (e) {
      debugPrint('🚨 [StorageService] Erro ao selecionar imagem: $e');
      return null;
    }
  }

  /// Uploads a file to a specific Supabase storage bucket
  Future<AppAttachment?> uploadFile({
    required String bucket,
    required String folder,
    required PickedFileData file,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw StateError('Usuário não autenticado.');
      final fileId = const Uuid().v4();
      final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      // A policy de storage exige que a primeira pasta seja o id do dono.
      final path = '$userId/$folder/${fileId}_$cleanName';

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(contentType: file.mimeType, upsert: true),
          );

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);

      return AppAttachment(
        id: fileId,
        name: file.name,
        url: publicUrl,
        size: file.size,
        mimeType: file.mimeType,
      );
    } catch (e, st) {
      debugPrint(
        '🚨 [StorageService] Erro no upload para o bucket $bucket: $e\n$st',
      );
      return null;
    }
  }

  /// Uploads a list of files to a specific Supabase storage bucket
  Future<List<Map<String, dynamic>>> uploadMultipleFiles({
    required String bucket,
    required String folderPath,
    required List<PickedFileData> files,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final file in files) {
      final res = await uploadFile(
        bucket: bucket,
        folder: folderPath,
        file: file,
      );
      if (res != null) {
        results.add(res.toJson());
      }
    }
    return results;
  }

  /// URL utilizável do arquivo: assinada para buckets privados, a própria nos demais.
  Future<String> resolveUrl(String url) async {
    final object = privateStorageObject(url);
    if (object == null) return url;
    return _supabase.storage
        .from(object.bucket)
        .createSignedUrl(object.path, signedUrlTtl.inSeconds);
  }

  /// Opens or downloads an attachment URL in external browser/viewer
  Future<bool> launchAttachment(String url) async {
    try {
      final uri = Uri.parse(await resolveUrl(url));
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('🚨 [StorageService] Erro ao abrir URL do anexo: $e');
      return false;
    }
  }

  String _guessMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return StorageService(supabase);
});

/// URL resolvida (assinada, se privada). Fica em cache um pouco menos que a
/// validade da assinatura, para não gerar uma nova a cada rebuild.
final resolvedStorageUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, url) async {
      final link = ref.keepAlive();
      final timer = Timer(
        signedUrlTtl - const Duration(minutes: 5),
        link.close,
      );
      ref.onDispose(timer.cancel);
      return ref.read(storageServiceProvider).resolveUrl(url);
    });
