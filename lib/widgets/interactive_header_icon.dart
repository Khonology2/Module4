import 'package:flutter/material.dart';

/// Header icon: shows [activeAsset] when [routeActive] or pointer hover, else [inactiveAsset].
/// Fixed hit size; optional [overlay] (e.g. unread badge) stacked on top.
class InteractiveHeaderIcon extends StatefulWidget {
  const InteractiveHeaderIcon({
    super.key,
    required this.inactiveAsset,
    required this.activeAsset,
    required this.routeActive,
    this.size = 44,
    this.overlay,
  });

  final String inactiveAsset;
  final String activeAsset;
  final bool routeActive;
  final double size;
  final Widget? overlay;

  @override
  State<InteractiveHeaderIcon> createState() => _InteractiveHeaderIconState();
}

class _InteractiveHeaderIconState extends State<InteractiveHeaderIcon> {
  bool _hover = false;

  bool get _useActive => widget.routeActive || _hover;

  @override
  Widget build(BuildContext context) {
    final asset =
        _useActive ? widget.activeAsset : widget.inactiveAsset;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(
              asset,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      ),
    );
  }
}
