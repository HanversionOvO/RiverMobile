import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Route<T> riverPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool enableFullScreenSwipeBack = true,
}) {
  if (fullscreenDialog || !enableFullScreenSwipeBack) {
    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  return CupertinoPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
  );
}
