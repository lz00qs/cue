import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String localeNameOf(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

String formatMonthYear(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(localeNameOf(context)).format(date);

String formatMonthName(BuildContext context, DateTime date) =>
    DateFormat.MMMM(localeNameOf(context)).format(date);

String formatLongDate(BuildContext context, DateTime date) =>
    DateFormat.MMMMEEEEd(localeNameOf(context)).format(date);

String formatMonthDay(BuildContext context, DateTime date) =>
    DateFormat.MMMMd(localeNameOf(context)).format(date);

String formatShortMonthDay(BuildContext context, DateTime date) =>
    DateFormat.MMMd(localeNameOf(context)).format(date);

String formatWeekday(BuildContext context, DateTime date) =>
    DateFormat.EEEE(localeNameOf(context)).format(date);

String formatNarrowWeekday(BuildContext context, DateTime date) =>
    DateFormat.EEEEE(localeNameOf(context)).format(date);
