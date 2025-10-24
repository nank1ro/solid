import 'package:flutter/widgets.dart';

/// {@template SolidAnnotations.SolidProvider}
/// A provider widget that supplies data of type T to its descendants.
/// It uses an InheritedWidget to propagate the data down the widget tree.
/// {@endtemplate}
class SolidProvider<T> extends StatefulWidget {
  /// {@macro SolidAnnotations.SolidProvider}
  const SolidProvider({
    super.key,
    required this.child,
    required this.create,
    this.notifyUpdate,
  });

  /// The function to create the data to be provided.
  final T Function(BuildContext context) create;

  /// The child widget which will have access to the provided data.
  final Widget child;

  /// Whether to notify the update of the provider, defaults to false.
  final bool Function(InheritedSolidProvider<T> oldWidget)? notifyUpdate;

  /// Retrieves the nearest SolidProvider of type T from the widget tree.
  /// Throws an error if no provider is found.
  static T of<T>(BuildContext context, {bool listen = true}) {
    final inherited = maybeOf<T>(context, listen: listen);
    if (inherited == null) {
      throw FlutterError(
        'Could not find SolidProvider<$T> in the ancestor widget tree. '
        'Make sure you have a SolidProvider<$T> widget as an ancestor of the '
        'widget that is trying to access it.',
      );
    }
    return inherited;
  }

  /// Retrieves the nearest SolidProvider of type T from the widget tree.
  /// Returns null if no provider is found.
  static T? maybeOf<T>(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<InheritedSolidProvider<T>>()
          ?.data;
    }
    final provider = context
        .getElementForInheritedWidgetOfExactType<InheritedSolidProvider<T>>()
        ?.widget;
    return (provider as InheritedSolidProvider<T>?)?.data;
  }

  @override
  State<SolidProvider<T>> createState() => _SolidProviderState<T>();
}

class _SolidProviderState<T> extends State<SolidProvider<T>> {
  late final T data;
  bool initialized = false;

  @override
  void dispose() {
    // Call dispose on the data
    (data as dynamic).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      data = widget.create(context);
      initialized = true;
    }
    return InheritedSolidProvider<T>(
      data: data,
      notifyUpdate: widget.notifyUpdate,
      child: widget.child,
    );
  }
}

/// {@template SolidAnnotations.InheritedSolidProvider}
/// An InheritedWidget that holds the provided data of type T.
/// It notifies its descendants when the data changes based on the
/// notifyUpdate callback.
/// {@endtemplate}
class InheritedSolidProvider<T> extends InheritedWidget {
  /// {@macro SolidAnnotations.InheritedSolidProvider}
  const InheritedSolidProvider({
    super.key,
    required super.child,
    required this.data,
    this.notifyUpdate,
  });

  /// The data to be provided
  final T data;

  /// Whether to notify the update of the provider, defaults to false
  final bool Function(InheritedSolidProvider<T> oldWidget)? notifyUpdate;

  @override
  bool updateShouldNotify(covariant InheritedSolidProvider<T> oldWidget) {
    return notifyUpdate?.call(oldWidget) ?? false;
  }
}
