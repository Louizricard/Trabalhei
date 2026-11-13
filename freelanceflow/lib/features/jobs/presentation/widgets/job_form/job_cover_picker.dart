import 'package:flutter/material.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';

/// Capa opcional da vaga: mostra a nova imagem escolhida ou a já salva,
/// com opção de trocar (toque) e remover.
class JobCoverPicker extends StatelessWidget {
  final PickedFileData? newCover;
  final String? savedUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const JobCoverPicker({
    super.key,
    required this.newCover,
    required this.savedUrl,
    required this.onPick,
    required this.onRemove,
  });

  ImageProvider? get _image {
    if (newCover case final file?) return MemoryImage(file.bytes);
    if (savedUrl case final url? when url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: image == null ? 'Adicionar capa da vaga' : 'Trocar capa da vaga',
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.primary.withAlpha(15),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null ? const _EmptyCover() : _removeButton(),
          ),
        ),
      ),
    );
  }

  Widget _removeButton() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          tooltip: 'Remover capa',
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _EmptyCover extends StatelessWidget {
  const _EmptyCover();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: AppColors.primary.withAlpha(150),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adicionar capa (opcional)',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'JPG, PNG ou WebP. Aparece no topo da vaga.',
          style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
        ),
      ],
    );
  }
}
