// Same setup as `query_with_cross_class_signal_unimported_type/`, but
// `widget.dart` ALSO imports `types.dart` directly. The generator must NOT
// double-add the import — the lib output's import block contains
// `types.dart` exactly once.

enum Unit { a, b }
