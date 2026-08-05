import 'package:flutter/material.dart';

/// Design tokens e paleta de cores oficial da marca **Trabalhei**.
/// 
/// Nenhuma tela ou componente deve declarar cores hardcoded;
/// utilize exclusivamente as constantes e utilitários desta classe.
class AppColors {
  // Brand Primary (Verde água / Esmeralda tecnológico)
  static const Color primary = Color(0xFF19E6A7);
  static const Color primaryDark = Color(0xFF12B783);
  static const Color primaryLight = Color(0xFF4EF3C1);
  static const Color primaryContainer = Color(0x2619E6A7); // 15% opacidade
  static const Color primaryGlow = Color(0x4D19E6A7); // 30% opacidade
  static const Color onPrimary = Color(0xFF081A2F); // Alto contraste sobre o verde
  static const Color onPrimaryLight = Color(0xFFFFFFFF); // Branco para botões / headers

  // Gradientes Primários
  static const Color primaryGradientStart = Color(0xFF19E6A7);
  static const Color primaryGradientEnd = Color(0xFF20D6A3);

  // Backgrounds e Superfícies (Startup Dark Mode)
  static const Color bgDark = Color(0xFF081A2F); // Fundo principal da aplicação
  static const Color surfaceDark = Color(0xFF102743); // Barras, bottom nav, appbar
  static const Color cardDark = Color(0xFF132B47); // Cards, containers e seções
  static const Color surfaceElevatedDark = Color(0xFF163252); // Modais, inputs, dropdowns
  static const Color borderDark = Color(0xFF223C58); // Bordas e divisores sutis
  static const Color borderSubtleDark = Color(0x40223C58); // Linhas de grid

  // Tipografia (Contraste premium)
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Textos principais e títulos
  static const Color textSecondaryDark = Color(0xFFB7C3D0); // Textos secundários
  static const Color textMutedDark = Color(0xFF7B8B99); // Placeholders, dicas e timestamps
  static const Color textDisabledDark = Color(0xFF475569);

  // Status & Feedback
  static const Color success = Color(0xFF19E6A7);
  static const Color successBg = Color(0x2619E6A7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x26F59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0x26EF4444);
  static const Color info = Color(0xFF38BDF8);
  static const Color infoBg = Color(0x2638BDF8);

  // Escrow & Segurança
  static const Color escrow = Color(0xFF19E6A7);
  static const Color escrowBg = Color(0x2619E6A7);

  // Mensagens & Chat
  static const Color chatBubbleSent = Color(0xFF0E4334);
  static const Color chatBubbleReceived = Color(0xFF132B47);
  static const Color chatBubbleSystem = Color(0xFF102743);

  // Neutral Light (Fallback / Adaptação)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF081A2F);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Cores universais acessíveis
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
}
