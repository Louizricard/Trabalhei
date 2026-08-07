/// Base class for all domain failures in Clean Architecture
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro ao se comunicar com o servidor.']);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Falha de autenticação. Verifique suas credenciais.',
  ]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso não encontrado.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Dados inválidos.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com a internet.']);
}
