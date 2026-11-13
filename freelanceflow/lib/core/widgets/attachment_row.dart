import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/attachment_rules.dart';

/// Ícone do tipo de arquivo, pela extensão do nome.
Widget fileTypeIcon(String name, {double size = 18}) {
  final (icon, color) = switch (fileExtension(name)) {
    'pdf' => (Icons.picture_as_pdf_rounded, AppColors.error),
    'png' ||
    'jpg' ||
    'jpeg' ||
    'webp' ||
    'gif' => (Icons.image_rounded, AppColors.primaryLight),
    'doc' || 'docx' => (Icons.description_rounded, AppColors.info),
    'zip' => (Icons.folder_zip_rounded, AppColors.warning),
    _ => (Icons.insert_drive_file_rounded, AppColors.textSecondaryDark),
  };
  return Icon(icon, size: size, color: color);
}

/// Linha de um anexo no formulário: nome, tipo, tamanho e ações.
class AttachmentRow extends StatelessWidget {
  final String name;
  final int size;
  final bool isNew;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  const AttachmentRow({
    super.key,
    required this.name,
    required this.size,
    this.isNew = false,
    this.onReplace,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ext = fileExtension(name).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          fileTypeIcon(name, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                Text(
                  [
                    if (ext.isNotEmpty) ext,
                    if (size > 0) formatBytes(size),
                    isNew ? 'novo, será enviado ao salvar' : 'já salvo',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (onReplace != null)
            IconButton(
              tooltip: 'Substituir $name',
              onPressed: onReplace,
              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
              color: AppColors.textSecondaryDark,
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remover $name',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}
