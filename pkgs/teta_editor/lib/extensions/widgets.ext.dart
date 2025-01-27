// Flutter imports:
import 'package:bounce/bounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motion/motion.dart';

extension WidgetUtils on Widget {
  SafeArea safeArea() => SafeArea(child: this);
  Center centered() => Center(child: this);
  Align aligned(Alignment alignment) =>
      Align(alignment: alignment, child: this);
  Padding padding(EdgeInsetsGeometry padding) => Padding(
        padding: padding,
        child: this,
      );
  Padding paddingAll(double padding) => Padding(
        padding: EdgeInsets.all(padding),
        child: this,
      );
  Padding paddingH(double padding) => Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: this,
      );
  Padding paddingV(double padding) => Padding(
        padding: EdgeInsets.symmetric(vertical: padding),
        child: this,
      );

  IgnorePointer ignored({required bool ignore}) => IgnorePointer(
        ignoring: ignore,
        child: this,
      );
  Opacity opacity(double opacity) => Opacity(
        opacity: opacity,
        child: this,
      );
  Visibility visible({required bool visible}) => Visibility(
        visible: visible,
        child: this,
      );
  Opacity hiddenButPresent() => ignored(ignore: true).opacity(0);
  DecoratedBox decorated(
    BoxDecoration decoration, {
    DecorationPosition position = DecorationPosition.background,
  }) =>
      DecoratedBox(decoration: decoration, position: position, child: this);
  ColoredBox color(Color color) => ColoredBox(color: color, child: this);
  ClipRect clippedRect() => ClipRect(
        child: this,
      );
  ClipRRect clippedRRect(BorderRadius borderRadius) => ClipRRect(
        borderRadius: borderRadius,
        child: this,
      );
  ClipOval clippedOval() => ClipOval(child: this);
  Expanded expanded({int flex = 1}) => Expanded(
        flex: flex,
        child: this,
      );
  Flexible flexible({int flex = 1, FlexFit fit = FlexFit.loose}) => Flexible(
        flex: flex,
        fit: fit,
        child: this,
      );
  Positioned positioned({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
  }) =>
      Positioned(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        width: width,
        height: height,
        child: this,
      );
  Positioned positionedFilled() => Positioned.fill(
        child: this,
      );
  Widget pointer({bool disable = false}) => disable
      ? this
      : MouseRegion(
          cursor: SystemMouseCursors.click,
          child: this,
        );
  SizedBox width(double width) => SizedBox(
        width: width,
        child: this,
      );
  SizedBox height(double height) => SizedBox(
        height: height,
        child: this,
      );
  SizedBox size(double width, double height) => SizedBox(
        width: width,
        height: height,
        child: this,
      );
  SizedBox square(double size) => SizedBox(
        width: size,
        height: size,
        child: this,
      );
  GestureDetector onTap(void Function() onTap) => GestureDetector(
        onTap: onTap,
        child: this,
      );
  Widget bounce({
    void Function()? onTap,
    void Function(TapDownDetails)? onLongPress,
    SystemMouseCursor? cursor,
    bool withMotion = false,
  }) {
    final bounce = Bounce(
      onTap: onTap,
      onLongPress: onLongPress,
      cursor: cursor ?? SystemMouseCursors.click,
      scaleFactor: 0.98,
      tilt: false,
      child: this,
    );
    if (withMotion) {
      return Motion(child: bounce);
    }
    return bounce;
  }

  Widget motion() => Motion(child: this);
  Widget bounceAndMotion({
    void Function()? onTap,
    void Function(TapDownDetails)? onLongPress,
    SystemMouseCursor? cursor,
  }) =>
      bounce(
        onTap: onTap,
        onLongPress: onLongPress,
        cursor: cursor,
        withMotion: true,
      );
  Widget aspectRatio(double ratio) => AspectRatio(
        aspectRatio: ratio,
        child: this,
      );
  ConstrainedBox constrained(BoxConstraints constraints) =>
      ConstrainedBox(constraints: constraints, child: this);
  FittedBox fitted({BoxFit fit = BoxFit.contain}) => FittedBox(
        fit: fit,
        child: this,
      );
  Tooltip tooltip(String message) => Tooltip(
        message: message,
        child: this,
      );
  RepaintBoundary repaintBoundary() => RepaintBoundary(child: this);
}

extension IconUtils on Icon {
  IconButton iconButton({required void Function() onTap}) => IconButton(
        onPressed: onTap,
        icon: this,
      );
}

extension TextUtils on Text {
  Text copyWith({
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
  }) =>
      Text(
        data ?? '',
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
      );
  Text color(Color color) => copyWith(style: style?.copyWith(color: color));
  Text bold() => copyWith(style: style?.copyWith(fontWeight: FontWeight.bold));
  Text italic() =>
      copyWith(style: style?.copyWith(fontStyle: FontStyle.italic));
  Text size(double size) => copyWith(style: style?.copyWith(fontSize: size));
  Text textAlign(TextAlign align) => copyWith(textAlign: align);
  Text maxLines(int lines) => copyWith(maxLines: lines);
  Text ellipsis() => copyWith(overflow: TextOverflow.ellipsis);
}
