/// Formata notas de avaliação. Usuários sem avaliações exibem "Novo" em vez de 0,0.
class RatingFormatter {
  static String format(double rating) =>
      rating <= 0 ? 'Novo' : rating.toStringAsFixed(1);
}
