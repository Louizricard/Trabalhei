import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/attachment_store.dart';
import '../../../../core/services/storage_service.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/proposal.dart';
import 'proposals_provider.dart';

/// Envia ou reenvia [proposal] com as amostras, sem deixar arquivo órfão:
/// sobe [newFiles] em `proposal_attachments/<uid>/<job_id>/`, grava a
/// proposta com [kept] + os novos e só então apaga [removed].
Future<void> submitProposalWithFiles(
  WidgetRef ref, {
  required Proposal proposal,
  required List<AppAttachment> kept,
  required List<AppAttachment> removed,
  required List<PickedFileData> newFiles,
}) async {
  await AttachmentSaveFlow(ref.read(storageServiceProvider)).run(
    bucket: 'proposal_attachments',
    folder: proposal.jobId,
    newFiles: newFiles,
    removed: removed,
    save: (uploaded) => ref
        .read(proposalRepositoryProvider)
        .submitProposal(
          proposal.copyWith(
            attachments: [
              for (final f in [...kept, ...uploaded]) f.toJson(),
            ],
          ),
        ),
  );
  ref.invalidate(freelancerProposalsProvider(proposal.freelancerId));
  ref.invalidate(jobProposalsProvider(proposal.jobId));
  ref.invalidate(jobDetailProvider(proposal.jobId));
  ref.invalidate(proposalQuotaProvider);
}
