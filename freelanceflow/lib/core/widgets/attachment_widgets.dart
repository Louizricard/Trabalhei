import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// Utilitários para detecção de tipo de anexo
class AttachmentHelper {
  static bool isImage(Map<String, dynamic> attachment) {
    final mime = (attachment['mime_type'] ?? attachment['mimeType'] ?? attachment['mime'] ?? '').toString().toLowerCase();
    if (mime.startsWith('image/')) return true;

    final name = (attachment['name'] ?? '').toString().toLowerCase();
    final url = (attachment['url'] ?? '').toString().toLowerCase();
    final ext = (name.split('.').lastOrNull ?? url.split('.').lastOrNull ?? '').toLowerCase();
    return ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'].contains(ext);
  }

  static String formatSize(dynamic rawSize) {
    final size = (rawSize is num) ? rawSize.toInt() : int.tryParse(rawSize?.toString() ?? '') ?? 0;
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Modal / Lightbox em tela cheia para visualização de imagens in-app sem redirecionamento externo
void showImageViewerGallery(
  BuildContext context, {
  required List<Map<String, dynamic>> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar Galeria',
    barrierColor: Colors.black.withAlpha(220),
    pageBuilder: (ctx, anim1, anim2) {
      return _ImageViewerDialog(images: images, initialIndex: initialIndex);
    },
  );
}

class _ImageViewerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const _ImageViewerDialog({
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index >= 0 && index < widget.images.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.images[_currentIndex];
    final currentName = currentImage['name'] as String? ?? 'Imagem ${_currentIndex + 1}';
    final currentUrl = currentImage['url'] as String? ?? '';
    final currentSize = AttachmentHelper.formatSize(currentImage['size']);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Efeito de blur no fundo
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: Colors.black.withAlpha(160)),
            ),
          ),

          // Visualizador de imagens com PageView e zoom
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final img = widget.images[index];
                final url = img['url'] as String? ?? '';

                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                          );
                        },
                        errorBuilder: (ctx, error, stackTrace) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.broken_image_rounded, size: 64, color: AppColors.error),
                            SizedBox(height: 12),
                            Text('Não foi possível carregar a imagem', style: TextStyle(color: AppColors.pureWhite)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Barra Superior com Informações e Ações
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    // Botão Fechar
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.pureWhite, size: 26),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),

                    // Título e tamanho da foto atual
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentName,
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentSize.isNotEmpty)
                            Text(
                              currentSize,
                              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                            ),
                        ],
                      ),
                    ),

                    // Badge de contagem (ex: 1 / 3)
                    if (widget.images.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevatedDark.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Text(
                          '${_currentIndex + 1} de ${widget.images.length}',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (currentUrl.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, color: AppColors.pureWhite, size: 20),
                        tooltip: 'Abrir original',
                        onPressed: () => launchUrl(Uri.parse(currentUrl), mode: LaunchMode.externalApplication),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Botões de navegação lateral (Anterior / Próximo)
          if (widget.images.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withAlpha(140),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.pureWhite, size: 36),
                      onPressed: () => _goTo(_currentIndex - 1),
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withAlpha(140),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.pureWhite, size: 36),
                      onPressed: () => _goTo(_currentIndex + 1),
                    ),
                  ),
                ),
              ),
          ],

          // Barra inferior com miniaturas (se houver mais de 1 imagem)
          if (widget.images.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withAlpha(200), Colors.transparent],
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.images.length, (idx) {
                          final isSelected = idx == _currentIndex;
                          final thumbUrl = widget.images[idx]['url'] as String? ?? '';

                          return GestureDetector(
                            onTap: () => _goTo(idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSelected ? 56 : 46,
                              height: isSelected ? 56 : 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.borderDark,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withAlpha(100),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  thumbUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: AppColors.surfaceDark,
                                    child: const Icon(Icons.image, color: AppColors.textMutedDark, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seletor de anexos para formulários
class AttachmentPickerSection extends ConsumerStatefulWidget {
  final List<PickedFileData> selectedFiles;
  final ValueChanged<List<PickedFileData>> onChanged;
  final String title;
  final String hintText;
  final int maxFiles;

  const AttachmentPickerSection({
    super.key,
    required this.selectedFiles,
    required this.onChanged,
    this.title = 'Anexos do Projeto (Opcional)',
    this.hintText = 'Adicionar Imagens, PDFs ou Documentos (máx. 15MB cada)',
    this.maxFiles = 5,
  });

  static Widget buildFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      return const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.error);
    }
    if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
      return const Icon(Icons.image_rounded, size: 18, color: AppColors.primaryLight);
    }
    if (['doc', 'docx'].contains(ext)) {
      return const Icon(Icons.description_rounded, size: 18, color: AppColors.info);
    }
    if (ext == 'zip') {
      return const Icon(Icons.folder_zip_rounded, size: 18, color: AppColors.warning);
    }
    return const Icon(Icons.insert_drive_file_rounded, size: 18, color: AppColors.textSecondaryDark);
  }

  @override
  ConsumerState<AttachmentPickerSection> createState() => _AttachmentPickerSectionState();
}

class _AttachmentPickerSectionState extends ConsumerState<AttachmentPickerSection> {
  bool _isPicking = false;

  Future<void> _pickFiles() async {
    if (widget.selectedFiles.length >= widget.maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limite de ${widget.maxFiles} anexos atingido.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isPicking = true);
    final storage = ref.read(storageServiceProvider);

    try {
      final picked = await storage.pickMultipleFiles(
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp', 'zip', 'txt'],
      );

      if (picked.isNotEmpty) {
        final current = List<PickedFileData>.from(widget.selectedFiles);
        for (final f in picked) {
          if (!current.any((c) => c.name == f.name) && current.length < widget.maxFiles) {
            current.add(f);
          }
        }
        widget.onChanged(current);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeFile(int index) {
    final current = List<PickedFileData>.from(widget.selectedFiles)..removeAt(index);
    widget.onChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryDark),
            ),
            Text(
              '${widget.selectedFiles.length}/${widget.maxFiles}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.hintText, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
        const SizedBox(height: 10),
        if (widget.selectedFiles.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.selectedFiles.length, (index) {
              final file = widget.selectedFiles[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AttachmentPickerSection.buildFileIcon(file.name),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        file.name,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('(${file.formattedSize})', style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _removeFile(index),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.borderDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isPicking ? null : _pickFiles,
          icon: _isPicking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(_isPicking ? 'Selecionando...' : 'Selecionar Arquivos'),
        ),
      ],
    );
  }
}

/// Visualizador Premium de Anexos em Formato de Galeria e Lista de Documentos
class AttachmentCardsList extends ConsumerWidget {
  final List<Map<String, dynamic>> attachments;
  final String title;

  const AttachmentCardsList({
    super.key,
    required this.attachments,
    this.title = 'Anexos da Vaga',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final storage = ref.read(storageServiceProvider);

    // Separar em imagens (Galeria) e documentos (Arquivos)
    final images = attachments.where(AttachmentHelper.isImage).toList();
    final documents = attachments.where((a) => !AttachmentHelper.isImage(a)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // SEÇÃO 1: GALERIA DE FOTOS E IMAGENS
        // ==========================================
        if (images.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                'Galeria de Fotos (${images.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: const Text(
                  'Clique para ampliar',
                  style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid de Imagens Inteligente
          _buildImageGrid(context, images),
          const SizedBox(height: 16),
        ],

        // ==========================================
        // SEÇÃO 2: DOCUMENTOS E ARQUIVOS (PDF, ZIP...)
        // ==========================================
        if (documents.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.description_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                'Documentos e Arquivos (${documents.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = documents[index];
              final name = data['name'] as String? ?? 'Arquivo ${index + 1}';
              final url = data['url'] as String? ?? '';
              final sizeStr = AttachmentHelper.formatSize(data['size']);

              return GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceElevatedDark,
                      child: AttachmentPickerSection.buildFileIcon(name),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sizeStr.isNotEmpty)
                            Text(sizeStr, style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: AppColors.primaryLight, size: 20),
                      tooltip: 'Baixar Documento',
                      onPressed: () {
                        if (url.isNotEmpty) {
                          storage.launchAttachment(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('URL do arquivo não disponível.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  /// Constrói a visualização em grade no formato galeria
  Widget _buildImageGrid(BuildContext context, List<Map<String, dynamic>> images) {
    if (images.length == 1) {
      // Única imagem em destaque
      return _buildImageCard(
        context,
        images: images,
        index: 0,
        height: 220,
      );
    }

    if (images.length == 2) {
      // Duas imagens lado a lado
      return Row(
        children: [
          Expanded(child: _buildImageCard(context, images: images, index: 0, height: 160)),
          const SizedBox(width: 12),
          Expanded(child: _buildImageCard(context, images: images, index: 1, height: 160)),
        ],
      );
    }

    // Três ou mais imagens: Layout de galeria fluido (grid)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return _buildImageCard(
          context,
          images: images,
          index: index,
        );
      },
    );
  }

  Widget _buildImageCard(
    BuildContext context, {
    required List<Map<String, dynamic>> images,
    required int index,
    double? height,
  }) {
    final data = images[index];
    final url = data['url'] as String? ?? '';
    final name = data['name'] as String? ?? 'Foto ${index + 1}';
    final sizeStr = AttachmentHelper.formatSize(data['size']);

    return InkWell(
      onTap: () => showImageViewerGallery(context, images: images, initialIndex: index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem com loading e erro elegantes
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surfaceDark,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (ctx, error, stackTrace) => Container(
                color: AppColors.surfaceDark,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: AppColors.error, size: 28),
                ),
              ),
            ),

            // Gradiente escuro na base para legibilidade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sizeStr.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        sizeStr,
                        style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Ícone de lupa/zoom no canto superior direito
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: AppColors.pureWhite,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
