import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/link_chips.dart';
import '../../domain/entities/proposal.dart';

/// Links e amostras enviados com a proposta, como o cliente os vê. Os
/// arquivos abrem por URL assinada (bucket privado). Some se vazio.
class ProposalPortfolioView extends StatelessWidget {
  final Proposal proposal;

  const ProposalPortfolioView({super.key, required this.proposal});

  @override
  Widget build(BuildContext context) {
    final links = proposal.portfolioLinks;
    final files = proposal.attachments;
    if (links.isEmpty && files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfólio e amostras:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 8),
            LinkChips(links: links),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            AttachmentCardsList(attachments: files, title: 'Arquivos'),
          ],
        ],
      ),
    );
  }
}
