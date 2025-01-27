// Package imports:
import 'package:gap/gap.dart';

extension NumberUtils on num {
  Gap get gap => Gap(toDouble());

  Duration get microseconds => Duration(microseconds: toInt());
  Duration get milliseconds => Duration(milliseconds: toInt());
  Duration get seconds => Duration(seconds: toInt());
  Duration get minutes => Duration(minutes: toInt());
  Duration get hours => Duration(hours: toInt());
  Duration get days => Duration(days: toInt());
  Duration get weeks => Duration(days: toInt() * 7);
  Duration get months => Duration(days: toInt() * 30);
  Duration get years => Duration(days: toInt() * 365);
}
