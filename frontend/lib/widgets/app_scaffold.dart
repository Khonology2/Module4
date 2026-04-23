import 'package:flutter/material.dart';
import 'background_image.dart';
import 'glass_card.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool useGlassContainer;
  final bool centered;
  final bool scrollable;
  final double? maxWidth;
  final EdgeInsetsGeometry contentPadding;
  final bool useBackgroundImage;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor = Colors.transparent,
    this.extendBodyBehindAppBar = false,
    this.useGlassContainer = true,
    this.centered = true,
    this.scrollable = true,
    this.maxWidth,
    this.contentPadding = const EdgeInsets.all(24.0),
    this.useBackgroundImage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: useBackgroundImage
          ? BackgroundImage(
              withGlassEffect: false,
              child: SafeArea(
                child: _buildContent(),
              ),
            )
          : SafeArea(child: _buildContent()),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildContent() {
    final core = useGlassContainer
        ? Padding(
            padding: contentPadding,
            child: GlassCard(
              padding: contentPadding,
              borderRadius: 16,
              blur: 20,
              child: body,
            ),
          )
        : body;

    final constrained = maxWidth != null
        ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: core,
            ),
          )
        : (centered ? Center(child: core) : core);

    if (scrollable) {
      return SingleChildScrollView(child: constrained);
    }
    return constrained;
  }
}
