import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import 'field_label.dart';

/// Tipo de um link, para ícone e rótulo (GitHub, LinkedIn, Behance...).
({String label, IconData icon}) linkKind(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  if (on('github.com')) return (label: 'GitHub', icon: Icons.code_rounded);
  if (on('linkedin.com')) {
    return (label: 'LinkedIn', icon: Icons.work_outline_rounded);
  }
  if (on('behance.net')) return (label: 'Behance', icon: Icons.brush_rounded);
  if (on('dribbble.com')) {
    return (label: 'Dribbble', icon: Icons.sports_basketball_rounded);
  }
  if (on('youtube.com') || on('youtu.be') || on('vimeo.com')) {
    return (label: 'Vídeo', icon: Icons.play_circle_outline_rounded);
  }
  if (on('instagram.com')) {
    return (label: 'Instagram', icon: Icons.photo_camera_outlined);
  }
  return (label: 'Site', icon: Icons.link_rounded);
}

/// Mensagem de erro ao adicionar [raw] numa lista com [current], ou null.
String? linkError(String raw, List<String> current, int maxLinks) {
  if (raw.trim().isEmpty) return 'Cole um link. Ex.: https://meusite.com.br';
  final error = Validators.optionalUrl(raw);
  if (error != null) return error;
  final url = Validators.normalizeUrl(raw).toLowerCase();
  if (current.any((l) => l.toLowerCase() == url)) {
    return 'Este link já está na lista.';
  }
  if (current.length >= maxLinks) return 'Você pode adicionar até $maxLinks.';
  return null;
}

/// Lista editável de links (portfólio, redes, amostras), com validação ao
/// adicionar, detecção do tipo e limite de [maxLinks].
class LinksInput extends StatefulWidget {
  final List<String> links;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final String helperText;
  final int maxLinks;
  final FieldRequirement requirement;

  const LinksInput({
    super.key,
    required this.links,
    required this.onChanged,
    this.title = 'Links',
    this.helperText = 'Ex.: https://behance.net/seunome ou o site do projeto.',
    this.maxLinks = 10,
    this.requirement = FieldRequirement.optional,
  });

  @override
  State<LinksInput> createState() => _LinksInputState();
}

class _LinksInputState extends State<LinksInput> {
  final _controller = TextEditingController();
  String? _error;

  bool get _full => widget.links.length >= widget.maxLinks;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final error = linkError(_controller.text, widget.links, widget.maxLinks);
    setState(() => _error = error);
    if (error != null) return;
    widget.onChanged([
      ...widget.links,
      Validators.normalizeUrl(_controller.text),
    ]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.title, requirement: widget.requirement),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('links-input-field'),
                controller: _controller,
                enabled: !_full,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: _full
                      ? 'Limite de ${widget.maxLinks} links atingido'
                      : 'https://',
                  helperText: _full ? null : widget.helperText,
                  errorText: _error,
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton.tonal(
                key: const Key('links-input-add'),
                onPressed: _full ? null : _add,
                child: const Text('Adicionar'),
              ),
            ),
          ],
        ),
        if (widget.links.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final (i, link) in widget.links.indexed)
            _LinkRow(
              url: link,
              onRemove: () => widget.onChanged([...widget.links]..removeAt(i)),
            ),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _LinkRow({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final kind = linkKind(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(kind.icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(
            kind.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remover link',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
