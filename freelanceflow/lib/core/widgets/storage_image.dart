import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// `Image.network` para arquivos do Supabase Storage. Em buckets privados,
/// busca uma URL assinada antes de carregar a imagem.
class StorageImage extends ConsumerWidget {
  final String url;
  final BoxFit? fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const StorageImage(
    this.url, {
    super.key,
    this.fit,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (privateStorageObject(url) == null) return _image(url);

    return ref
        .watch(resolvedStorageUrlProvider(url))
        .when(
          data: _image,
          loading: () =>
              loadingBuilder?.call(
                context,
                const SizedBox.shrink(),
                const ImageChunkEvent(
                  cumulativeBytesLoaded: 0,
                  expectedTotalBytes: null,
                ),
              ) ??
              const SizedBox.shrink(),
          error: (error, stackTrace) =>
              errorBuilder?.call(context, error, stackTrace) ??
              const SizedBox.shrink(),
        );
  }

  Widget _image(String resolvedUrl) => Image.network(
    resolvedUrl,
    fit: fit,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
