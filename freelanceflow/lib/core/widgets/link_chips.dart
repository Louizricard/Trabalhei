import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import 'links_input.dart';

/// Links clicáveis em chips, com ícone do tipo (GitHub, Behance, site...).
/// Abrem fora do app.
class LinkChips extends StatelessWidget {
  final List<String> links;

  const LinkChips({super.key, required this.links});

  static String _shortLabel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path.length > 1 ? uri.path : '';
    final text = '${uri.host.replaceFirst('www.', '')}$path';
    return text.length > 40 ? '${text.substring(0, 39)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links)
          ActionChip(
            avatar: Icon(
              linkKind(link).icon,
              size: 16,
              color: AppColors.primaryLight,
            ),
            label: Text(_shortLabel(link)),
            tooltip: link,
            onPressed: () => launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ],
    );
  }
}
