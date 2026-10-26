import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/job_alert_repository.dart';
import '../../domain/entities/job_alert.dart';

final jobAlertRepositoryProvider = Provider<JobAlertRepository>(
  (ref) => JobAlertRepository(ref.watch(supabaseClientProvider)),
);

final jobAlertsProvider = FutureProvider.autoDispose<List<JobAlert>>(
  (ref) => ref.watch(jobAlertRepositoryProvider).list(),
);
