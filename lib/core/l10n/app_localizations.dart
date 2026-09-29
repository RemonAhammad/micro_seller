import 'package:flutter/material.dart';
import 'translations_en.dart';
import 'translations_bn.dart';
import 'translations_ar.dart';
import 'translations_es.dart';
import 'translations_fr.dart';
import 'translations_pt.dart';
import 'translations_tr.dart';
import 'translations_id.dart';
import 'translations_th.dart';
import 'translations_vi.dart';
import 'translations_ur.dart';
import 'translations_ms.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('bn'),
    Locale('ar'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('tr'),
    Locale('id'),
    Locale('th'),
    Locale('vi'),
    Locale('ur'),
    Locale('ms'),
  ];

  static const _codes = [
    'en', 'bn', 'ar', 'es', 'fr', 'pt', 'tr', 'id', 'th', 'vi', 'ur', 'ms'
  ];

  static const languageNames = <String, String>{
    'en': 'English',
    'bn': 'বাংলা',
    'ar': 'العربية',
    'es': 'Español',
    'fr': 'Français',
    'pt': 'Português',
    'tr': 'Türkçe',
    'id': 'Bahasa Indonesia',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'ur': 'اردو',
    'ms': 'Bahasa Melayu',
  };

  Map<String, String> get _translations {
    switch (locale.languageCode) {
      case 'bn':
        return translationsBn;
      case 'ar':
        return translationsAr;
      case 'es':
        return translationsEs;
      case 'fr':
        return translationsFr;
      case 'pt':
        return translationsPt;
      case 'tr':
        return translationsTr;
      case 'id':
        return translationsId;
      case 'th':
        return translationsTh;
      case 'vi':
        return translationsVi;
      case 'ur':
        return translationsUr;
      case 'ms':
        return translationsMs;
      default:
        return translationsEn;
    }
  }

  // English fallback so a key missing from one locale shows readable text
  // instead of the raw key name.
  String tr(String key) => _translations[key] ?? translationsEn[key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._codes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate old) => false;
}
