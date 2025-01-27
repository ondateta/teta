import 'package:editor/extensions/numbers.ext.dart';
import 'package:flutter/widgets.dart';

extension WidgetListUtils on List<Widget> {
  List<Widget> spacing(double spacer) {
    final spacedList = <Widget>[];
    for (var i = 0; i < length; i++) {
      spacedList.add(this[i]);
      if (i != length - 1) {
        spacedList.add(spacer.gap);
      }
    }
    return spacedList;
  }

  List<Widget> separatedBy(Widget separator) {
    final separatedList = <Widget>[];
    for (var i = 0; i < length; i++) {
      separatedList.add(this[i]);
      if (i != length - 1) {
        separatedList.add(separator);
      }
    }
    return separatedList;
  }

  Column column({
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.start,
    MainAxisSize size = MainAxisSize.min,
  }) {
    return Column(
      mainAxisAlignment: main,
      crossAxisAlignment: cross,
      mainAxisSize: size,
      children: this,
    );
  }

  Row row({
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.start,
    MainAxisSize size = MainAxisSize.min,
  }) {
    return Row(
      mainAxisAlignment: main,
      crossAxisAlignment: cross,
      mainAxisSize: size,
      children: this,
    );
  }

  Wrap wrap({
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    WrapAlignment alignment2 = WrapAlignment.start,
    WrapCrossAlignment alignment3 = WrapCrossAlignment.start,
    double spacing = 0.0,
    double runSpacing = 0.0,
    WrapAlignment runAlignment = WrapAlignment.start,
    List<Widget> children = const <Widget>[],
  }) {
    return Wrap(
      direction: direction,
      alignment: alignment,
      runAlignment: runAlignment,
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: alignment3,
      children: this,
    );
  }

  Stack stack() {
    return Stack(
      children: this,
    );
  }

  Widget listView({
    ScrollController? controller,
    EdgeInsets? padding,
    bool? isPrimary,
    Axis direction = Axis.vertical,
    ScrollPhysics? physics,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      primary: isPrimary,
      scrollDirection: direction,
      physics: physics,
      itemCount: length,
      itemBuilder: (context, index) => this[index],
    );
  }

  Flex flex({
    Axis direction = Axis.horizontal,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.start,
    TextDirection? textDirection,
    VerticalDirection? verticalDirection,
    TextBaseline? textBaseline,
  }) {
    return Flex(
      direction: direction,
      mainAxisAlignment: main,
      crossAxisAlignment: cross,
      textDirection: textDirection,
      verticalDirection: verticalDirection ?? VerticalDirection.down,
      textBaseline: textBaseline,
      children: this,
    );
  }
}

extension FutureListUtils<T> on List<Future<T>> {
  Future<List<T>> waitAll() async {
    return Future.wait<T>(this);
  }
}
