/// Mensagens amigáveis para os erros conhecidos do backend. O texto técnico
/// nunca chega à tela: vai para o log (ver `error_reporter.dart`).
library;

/// Códigos levantados pelas funções do banco (`raise exception 'CODE'`).
const Map<String, String> databaseCodes = {
  'NOT_AUTHENTICATED': 'Faça login para continuar.',
  'FORBIDDEN': 'Você não tem permissão para esta ação.',
  'PROPOSAL_QUOTA_EXCEEDED':
      'Você usou todas as propostas deste mês. O saldo renova no dia 1º; no Pro são mais propostas por mês.',
  'DAILY_PROPOSAL_LIMIT':
      'Você atingiu o limite de propostas das últimas 24 horas. Aguarde um pouco para enviar mais.',
  'COVER_LETTER_TOO_SHORT':
      'Sua carta de apresentação está curta. Conte por que você é a pessoa certa para esta vaga.',
  'TEMPLATE_LIMIT_REACHED':
      'Você chegou ao limite de modelos. Apague um para criar outro.',
  'PRO_REQUIRED': 'Este recurso é do plano Pro.',
  'COUPON_INVALID': 'Cupom inválido. Confira o código.',
  'COUPON_NOT_FOR_PRODUCT': 'Este cupom não vale para este produto.',
  'COUPON_EXPIRED': 'Este cupom expirou ou ainda não começou a valer.',
  'COUPON_EXHAUSTED': 'Este cupom já atingiu o limite de usos.',
  'COUPON_ALREADY_USED': 'Você já usou este cupom.',
  'PRODUCT_UNAVAILABLE': 'Este produto não está disponível no momento.',
  'ONLY_FREELANCERS_CAN_APPLY':
      'Apenas contas de freelancer podem enviar propostas.',
  'ONLY_CLIENTS_CAN_POST_JOBS':
      'Apenas contas de cliente podem publicar vagas.',
  'JOB_NOT_OPEN': 'Esta vaga não está mais aberta.',
  'JOB_NOT_CANCELLABLE': 'Esta vaga não pode ser cancelada.',
  'CANNOT_APPLY_TO_OWN_JOB': 'Você não pode se candidatar à sua própria vaga.',
  'PROPOSAL_ALREADY_DECIDED': 'Esta proposta já foi decidida.',
  'PROPOSAL_NOT_FOUND': 'Proposta não encontrada.',
  'PROPOSAL_NOT_PENDING': 'Esta proposta não está mais pendente.',
  'NO_ACTIVE_COUNTER_OFFER': 'Não há contraproposta ativa nesta proposta.',
  'INVALID_COUNTER_OFFER': 'Valor ou prazo da contraproposta inválido.',
  'MILESTONE_NOT_FOUND': 'Marco não encontrado.',
  'MILESTONE_NOT_DELIVERABLE': 'Este marco não aceita entregas agora.',
  'MILESTONE_NOT_SUBMITTED': 'Este marco não possui entrega para analisar.',
  'CONTRACT_NOT_ACTIVE': 'Este contrato não está ativo.',
  'COMMENT_REQUIRED': 'Descreva o que precisa ser ajustado.',
  'CANNOT_MODERATE_SELF': 'Você não pode moderar a própria conta.',
  'CANNOT_MODERATE_ADMIN': 'Não é possível suspender outro administrador.',
  'REASON_REQUIRED': 'Informe o motivo.',
  'USER_NOT_FOUND_OR_SUSPENDED': 'Esta conta já está suspensa ou não existe.',
  'USER_NOT_SUSPENDED': 'Esta conta não está suspensa.',
  'REPORT_NOT_FOUND': 'Esta denúncia já foi analisada.',
  'ALERT_LIMIT_REACHED':
      'Você pode ter até 10 alertas. Apague um para criar outro.',
};

/// Registros únicos (nome do índice no banco).
const Map<String, String> uniqueConstraints = {
  'reports_one_open_per_target':
      'Você já denunciou isto. A moderação vai analisar em breve.',
  'coupons_pkey': 'Já existe um cupom com esse código.',
  'push_subscriptions_endpoint_key':
      'As notificações já estão ativas neste navegador.',
};

/// Restrições de tamanho e valor das tabelas (nome da constraint no banco).
const Map<String, String> checkConstraints = {
  'profiles_bio_check': 'A bio pode ter até 2.000 caracteres.',
  'profiles_full_name_check': 'O nome deve ter entre 1 e 120 caracteres.',
  'profiles_company_name_check':
      'O nome da empresa pode ter até 120 caracteres.',
  'profiles_headline_check':
      'O título profissional pode ter até 80 caracteres.',
  'profiles_location_check': 'A cidade pode ter até 80 caracteres.',
  'profiles_links_check': 'Use links completos, começando com https://.',
  'profiles_hourly_rate_check': 'O valor por hora não pode ser negativo.',
  'jobs_title_check': 'O título deve ter entre 3 e 140 caracteres.',
  'jobs_description_check': 'A descrição precisa de pelo menos 10 caracteres.',
  'jobs_budget_range': 'O orçamento máximo deve ser maior ou igual ao mínimo.',
  'jobs_budget_min_check': 'O orçamento não pode ser negativo.',
  'jobs_deadline_days_check': 'O prazo deve ser de pelo menos 1 dia.',
  'proposals_bid_amount_check': 'O valor da proposta deve ser maior que zero.',
  'proposals_estimated_days_check': 'O prazo deve ser de pelo menos 1 dia.',
  'messages_content_check': 'A mensagem pode ter até 5.000 caracteres.',
  'reviews_comment_check': 'O comentário pode ter até 2.000 caracteres.',
  'portfolio_items_title_check': 'O título deve ter entre 1 e 120 caracteres.',
};

/// Erros do login e cadastro (código do Supabase Auth ou trecho da mensagem).
const Map<String, String> authErrors = {
  'invalid_credentials': 'E-mail ou senha incorretos.',
  'invalid login credentials': 'E-mail ou senha incorretos.',
  'email_address_invalid':
      'Este e-mail não é válido. Confira se digitou certo.',
  'error sending confirmation email':
      'Não conseguimos enviar o e-mail de confirmação. Confira se o endereço está correto e tente de novo.',
  'error sending recovery email':
      'Não conseguimos enviar o e-mail de redefinição. Confira se o endereço está correto e tente de novo.',
  'user_already_exists': 'Este e-mail já tem uma conta.',
  'already registered': 'Este e-mail já tem uma conta.',
  'weak_password': 'Escolha uma senha mais forte, com pelo menos 8 caracteres.',
  'password should be at least': 'A senha deve ter pelo menos 8 caracteres.',
  'same_password': 'A nova senha precisa ser diferente da atual.',
  'over_email_send_rate_limit':
      'Muitos e-mails enviados em pouco tempo. Aguarde alguns minutos e tente de novo.',
  'over_request_rate_limit':
      'Muitas tentativas. Aguarde alguns instantes e tente de novo.',
  'rate limit': 'Muitas tentativas. Aguarde alguns instantes e tente de novo.',
  'for security purposes': 'Aguarde alguns segundos antes de tentar de novo.',
  'otp_expired': 'O link expirou ou já foi usado. Peça um novo.',
  'session_not_found': 'Sua sessão expirou. Entre de novo.',
  'refresh_token_not_found': 'Sua sessão expirou. Entre de novo.',
  'signup_disabled': 'Novos cadastros estão temporariamente desativados.',
  'user_banned':
      'Esta conta está suspensa. Se acha que foi um engano, fale com o suporte.',
};

/// Erros de upload no Storage.
const Map<String, String> storageErrors = {
  'mime type': 'Formato de arquivo não aceito.',
  'invalid_mime_type': 'Formato de arquivo não aceito.',
  'payload too large': 'O arquivo é maior que o permitido.',
  'maximum allowed size': 'O arquivo é maior que o permitido.',
  'entitytoolarge': 'O arquivo é maior que o permitido.',
};

const String networkError =
    'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
const String unexpectedError =
    'Algo deu errado do nosso lado. Tente de novo em instantes.';
