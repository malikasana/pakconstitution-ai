import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light theme
  static const lightBg = Color(0xFFF8F8F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF1F0EC);
  static const lightBorder = Color(0xFFE8E6E0);
  static const lightBorder2 = Color(0xFFD4D0C8);
  static const lightText = Color(0xFF18181B);
  static const lightText2 = Color(0xFF52525B);
  static const lightText3 = Color(0xFFA1A1AA);

  // Dark theme
  static const darkBg = Color(0xFF18181B);
  static const darkSurface = Color(0xFF1F1F23);
  static const darkSurface2 = Color(0xFF27272A);
  static const darkBorder = Color(0xFF3F3F46);
  static const darkBorder2 = Color(0xFF52525B);
  static const darkText = Color(0xFFFAFAFA);
  static const darkText2 = Color(0xFFA1A1AA);
  static const darkText3 = Color(0xFF52525B);

  // Sidebar — always dark on both themes
  static const sidebarBg = Color(0xFF111113);
  static const sidebarBorder = Color(0xFF1F1F23);
  static const sidebarText = Color(0xCCFFFFFF);
  static const sidebarMuted = Color(0x47FFFFFF);
  static const sidebarItem = Color(0x0DFFFFFF);
  static const sidebarActive = Color(0x1AFFFFFF);
  static const sidebarDivider = Color(0x12FFFFFF);
  // Dark theme sidebar right border — visible edge
  static const sidebarEdgeBorder = Color(0x1FFFFFFF);

  // User bubble
  static const lightUserBubble = Color(0xFF18181B);
  static const lightUserText = Color(0xFFFAFAFA);
  static const darkUserBubble = Color(0xFF27272A);
  static const darkUserText = Color(0xFFFAFAFA);

  // Reference card — light
  static const refBgLight = Color(0xFFFAFAF9);
  static const refBorderLight = Color(0xFFE4E2DC);
  static const refAccentLight = Color(0xFF92400E);
  static const refExcerptBgLight = Color(0xFFFEF3C7);
  static const refBadgeBgLight = Color(0xFF1C1C1E);
  static const refBadgeTextLight = Color(0xFFF5F5F5);
  static const amendBgLight = Color(0xFFF0FDF4);
  static const amendTextLight = Color(0xFF166534);
  static const amendBorderLight = Color(0xFFBBF7D0);

  // Reference card — dark
  static const refBgDark = Color(0xFF1F1F23);
  static const refBorderDark = Color(0xFF3F3F46);
  static const refAccentDark = Color(0xFFD97706);
  static const refExcerptBgDark = Color(0xFF1C1407);
  static const refBadgeBgDark = Color(0xFFFAFAFA);
  static const refBadgeTextDark = Color(0xFF18181B);
  static const amendBgDark = Color(0xFF052E16);
  static const amendTextDark = Color(0xFF86EFAC);
  static const amendBorderDark = Color(0xFF166534);

  // Accent
  static const accentLight = Color(0xFF2563EB);
  static const accentDark = Color(0xFF60A5FA);

  // Status
  static const online = Color(0xFF22C55E);
}