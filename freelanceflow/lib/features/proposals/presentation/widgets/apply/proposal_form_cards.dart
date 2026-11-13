import 'package:flutter/material.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/utils/input_formatters.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/attachment_picker_section.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../../../core/widgets/custom_text_field.dart';
import '../../../../../core/widgets/field_label.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/links_input.dart';

const _titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);

/// Valor total e prazo da proposta, com máscara e limites do servidor.
class ProposalTermsCard extends StatelessWidget {
  final TextEditingController bidController;
  final TextEditingController daysController;

  const ProposalTermsCard({
    super.key,
    required this.bidController,
    required this.daysController,
  });

  @override
  Widget build(BuildContext context) {
    final bid = CustomTextField(
      controller: bidController,
      label: 'Valor total',
      prefixText: 'R\$ ',
      hint: '1.500,00',
      helperText: 'Quanto você cobra pelo projeto inteiro.',
      requirement: FieldRequirement.required,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [CurrencyInputFormatter()],
      textInputAction: TextInputAction.next,
      validator: Validators.money(),
    );
    final days = CustomTextField(
      controller: daysController,
      label: 'Prazo de entrega',
      hint: '15',
      helperText: 'Em dias corridos. Ex.: 15 dias.',
      requirement: FieldRequirement.required,
      keyboardType: TextInputType.number,
      inputFormatters: const [IntegerInputFormatter(maxDigits: 3)],
      textInputAction: TextInputAction.next,
      validator: Validators.intRange(1, 365, unit: 'dias'),
    );
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Termos da proposta', style: _titleStyle),
          const SizedBox(height: 4),
          const RequiredFieldsNote(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 420
                ? Column(children: [bid, const SizedBox(height: 12), days])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bid),
                      const SizedBox(width: 12),
                      Expanded(child: days),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Carta de apresentação, com mínimo definido no servidor e atalho para
/// os modelos salvos.
class CoverLetterCard extends StatelessWidget {
  final TextEditingController controller;
  final int minChars;
  final VoidCallback onUseTemplate;

  const CoverLetterCard({
    super.key,
    required this.controller,
    required this.minChars,
    required this.onUseTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Carta de apresentação', style: _titleStyle),
              ),
              TextButton.icon(
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Modelos'),
                onPressed: onUseTemplate,
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: controller,
            label: 'Por que você é a pessoa certa para este trabalho?',
            requirement: FieldRequirement.required,
            hint:
                'Conte experiências parecidas, como vai conduzir o trabalho '
                'e o que o cliente recebe ao final.',
            helperText: 'Mínimo de $minChars caracteres.',
            maxLines: 6,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            validator: Validators.minLength(
              'a carta de apresentação',
              minChars,
            ),
          ),
        ],
      ),
    );
  }
}

/// Links e arquivos que mostram trabalhos anteriores. Os arquivos ficam
/// privados: só o dono da vaga e o autor da proposta abrem.
class ProposalPortfolioCard extends StatelessWidget {
  final List<String> links;
  final ValueChanged<List<String>> onLinksChanged;
  final List<AppAttachment> existingFiles;
  final ValueChanged<List<AppAttachment>> onExistingFilesChanged;
  final List<PickedFileData> newFiles;
  final ValueChanged<List<PickedFileData>> onNewFilesChanged;

  const ProposalPortfolioCard({
    super.key,
    required this.links,
    required this.onLinksChanged,
    required this.existingFiles,
    required this.onExistingFilesChanged,
    required this.newFiles,
    required this.onNewFilesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Portfólio e amostras (opcional)', style: _titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Mostre trabalhos parecidos com o que o cliente pediu. '
            'Só o cliente desta vaga vê os arquivos.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          LinksInput(
            title: 'Links de trabalhos',
            links: links,
            onChanged: onLinksChanged,
          ),
          const SizedBox(height: 16),
          AttachmentPickerSection(
            title: 'Arquivos de amostra (opcional)',
            hintText: 'PDF, imagens, documentos ou ZIP. Até 5 arquivos.',
            existing: existingFiles,
            onExistingChanged: onExistingFilesChanged,
            selectedFiles: newFiles,
            onChanged: onNewFilesChanged,
          ),
        ],
      ),
    );
  }
}

/// Botão de envio ou, quando a proposta não pode mais ser alterada, o motivo.
class ProposalSubmitArea extends StatelessWidget {
  final String? blockedReason;
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onSubmit;

  const ProposalSubmitArea({
    super.key,
    required this.blockedReason,
    required this.isEditing,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (blockedReason case final reason?) {
      return Text(
        reason,
        key: const Key('proposal-blocked-reason'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondaryDark,
        ),
      );
    }
    return CustomButton(
      text: isEditing ? 'Salvar alterações' : 'Enviar proposta',
      icon: isEditing ? Icons.save_rounded : Icons.send_rounded,
      isLoading: isLoading,
      width: double.infinity,
      onPressed: onSubmit,
    );
  }
}
