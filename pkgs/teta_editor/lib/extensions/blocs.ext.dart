// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_bloc/flutter_bloc.dart';

extension ListenableUtils on Widget {
  BlocListener<B, S> listen<B extends BlocBase<S>, S>({
    BlocListenerCondition<S>? when,
    required void Function(BuildContext context, S state) listener,
  }) =>
      BlocListener<B, S>(
        listenWhen: when,
        listener: listener,
        child: this,
      );
}
