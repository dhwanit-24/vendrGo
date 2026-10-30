import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Spacing scale used for padding, gaps and margins.
class VendrgoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Corner radii.
class VendrgoRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Soft elevation shadows (cards float rather than sit in a border).
class VendrgoShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

/// Typography scale. Font family comes from the theme (Plus Jakarta Sans).
class VendrgoText {
  static const String fontFamily = 'PlusJakartaSans';

  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: VendrgoColors.text,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: VendrgoColors.text,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: VendrgoColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: VendrgoColors.text,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: VendrgoColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: VendrgoColors.text,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: VendrgoColors.textSecondary,
  );
}
