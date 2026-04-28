import 'dart:ui';

import 'package:flutter/material.dart';

const double _modalBackdropBlur = 6.0;
const double _modalBackdropOpacity = 0.6;

Widget _buildModalBackdrop() {
  return Positioned.fill(
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: _modalBackdropBlur,
        sigmaY: _modalBackdropBlur,
      ),
      child: Container(
        color: Colors.black.withValues(alpha: _modalBackdropOpacity),
      ),
    ),
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      return SizedBox.expand(
        child: Stack(
          children: [
            _buildModalBackdrop(),
            SafeArea(
              child: Center(
                child: Builder(builder: builder),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (sheetContext) {
      return SizedBox.expand(
        child: Stack(
          children: [
            _buildModalBackdrop(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Builder(builder: builder),
            ),
          ],
        ),
      );
    },
  );
}

