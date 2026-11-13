import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../../features/billing/presentation/providers/pricing_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/attachment_rules.dart';
import 'attachment_row.dart';

/// Gerencia os anexos de um formulário: os já salvos ([existing]) e os novos
/// ([selectedFiles]), com remover, substituir e limite total de [maxFiles].
///
/// O widget só altera listas; enviar e apagar arquivos é papel de quem salva
/// (ver `AttachmentSaveFlow`).
class AttachmentPickerSection extends ConsumerStatefulWidget {
  final List<PickedFileData> selectedFiles;
  final ValueChanged<List<PickedFileData>> onChanged;
  final List<AppAttachment> existing;
  final ValueChanged<List<AppAttachment>>? onExistingChanged;
  final String title;
  final String hintText;
  final int maxFiles;
  final List<String> extensions;

  const AttachmentPickerSection({
    super.key,
    required this.selectedFiles,
    required this.onChanged,
    this.existing = const [],
    this.onExistingChanged,
    this.title = 'Anexos (opcional)',
    this.hintText =
        'Imagens, PDFs ou documentos que ajudem a entender o pedido.',
    this.maxFiles = 5,
    this.extensions = defaultAttachmentExtensions,
  });

  @override
  ConsumerState<AttachmentPickerSection> createState() =>
      _AttachmentPickerSectionState();
}

class _AttachmentPickerSectionState
    extends ConsumerState<AttachmentPickerSection> {
  bool _isPicking = false;

  int get _total => widget.existing.length + widget.selectedFiles.length;
  Iterable<String> get _names => [
    ...widget.existing.map((a) => a.name),
    ...widget.selectedFiles.map((f) => f.name),
  ];

  Future<void> _add() async {
    final picked = await _pick(multiple: true);
    if (picked.isEmpty) return;
    final selection = _select(picked, _names, widget.maxFiles - _total);
    if (selection.accepted.isNotEmpty) {
      widget.onChanged([...widget.selectedFiles, ...selection.accepted]);
    }
  }

  /// Troca um anexo (salvo ou novo) por outro arquivo, na mesma vaga da lista.
  Future<void> _replace({int? existingIndex, int? newIndex}) async {
    final picked = await _pick(multiple: false);
    if (picked.isEmpty) return;
    final others = _names.where(
      (n) =>
          n !=
          (existingIndex != null
              ? widget.existing[existingIndex].name
              : widget.selectedFiles[newIndex!].name),
    );
    final selection = _select(picked, others, 1);
    if (selection.accepted.isEmpty) return;
    final files = [...widget.selectedFiles];
    if (existingIndex != null) {
      widget.onExistingChanged?.call(
        [...widget.existing]..removeAt(existingIndex),
      );
      files.add(selection.accepted.single);
    } else {
      files[newIndex!] = selection.accepted.single;
    }
    widget.onChanged(files);
  }

  Future<List<PickedFileData>> _pick({required bool multiple}) async {
    setState(() => _isPicking = true);
    try {
      final storage = ref.read(storageServiceProvider);
      if (multiple) {
        return await storage.pickMultipleFiles(
          allowedExtensions: widget.extensions,
        );
      }
      final file = await storage.pickFile(allowedExtensions: widget.extensions);
      return file == null ? [] : [file];
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  AttachmentSelection<PickedFileData> _select(
    List<PickedFileData> picked,
    Iterable<String> names,
    int slots,
  ) {
    final limit = ref.read(uploadLimitBytesProvider);
    final selection = selectAttachments<PickedFileData>(
      picked: picked,
      nameOf: (f) => f.name,
      sizeOf: (f) => f.size,
      currentNames: names,
      remainingSlots: slots,
      limitBytes: limit,
      extensions: widget.extensions,
    );
    if (selection.hasRejections) _warn(selection, limit);
    return selection;
  }

  void _warn(AttachmentSelection<PickedFileData> selection, int limit) {
    final isPro = ref.read(authProvider).valueOrNull?.isPro ?? false;
    final lines = selection.messages(
      limitBytes: limit,
      maxFiles: widget.maxFiles,
      extensions: widget.extensions,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lines.join('\n')),
        backgroundColor: AppColors.warning,
        action: selection.tooBig.isNotEmpty && !isPro
            ? SnackBarAction(
                label: 'Ver o Pro',
                onPressed: () => context.push('/plans'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(uploadLimitBytesProvider);
    final full = _total >= widget.maxFiles;
    final types = widget.extensions
        .where((e) => e != 'jpeg')
        .map((e) => e.toUpperCase())
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            Text(
              '$_total de ${widget.maxFiles}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMutedDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.hintText} $types, até ${formatBytes(limit)} cada.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < widget.existing.length; i++)
          AttachmentRow(
            name: widget.existing[i].name,
            size: widget.existing[i].size,
            onReplace: widget.onExistingChanged == null || _isPicking
                ? null
                : () => _replace(existingIndex: i),
            onRemove: widget.onExistingChanged == null
                ? null
                : () => widget.onExistingChanged!(
                    [...widget.existing]..removeAt(i),
                  ),
          ),
        for (var i = 0; i < widget.selectedFiles.length; i++)
          AttachmentRow(
            name: widget.selectedFiles[i].name,
            size: widget.selectedFiles[i].size,
            isNew: true,
            onReplace: _isPicking ? null : () => _replace(newIndex: i),
            onRemove: () =>
                widget.onChanged([...widget.selectedFiles]..removeAt(i)),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.borderDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isPicking || full ? null : _add,
          icon: _isPicking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(
            _isPicking
                ? 'Selecionando...'
                : full
                ? 'Limite de anexos atingido'
                : 'Adicionar arquivos',
          ),
        ),
      ],
    );
  }
}
