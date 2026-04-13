import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/flownet_theme.dart';

/// Full-bleed circular AI assistant control (PNG includes gradient and shadow).
/// Used by [SidebarScaffold] and by screens that stack their own FAB above it
/// (e.g. timeline calendar).
class AiAssistantFabButton extends StatefulWidget {
  const AiAssistantFabButton({super.key});

  static const String assetPath = 'assets/Icons/ai_assistant_icon.png';
  static const double fabSize = 56;

  @override
  State<AiAssistantFabButton> createState() => _AiAssistantFabButtonState();
}

class _AiAssistantFabButtonState extends State<AiAssistantFabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    return Hero(
      tag: 'sidebar_ai_assistant_fab',
      child: Tooltip(
        message: 'AI Assistant',
        child: SizedBox(
          width: AiAssistantFabButton.fabSize,
          height: AiAssistantFabButton.fabSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    final v = pulse.value;
                    // Strong brand red ↔ soft white (smooth halo, not harsh).
                    final coreGlow = Color.lerp(
                      FlownetColors.crimsonRed.withValues(alpha: 0.78),
                      Colors.white.withValues(alpha: 0.48),
                      v,
                    )!;
                    final outerGlow = Color.lerp(
                      FlownetColors.crimsonRed.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0.26),
                      v,
                    )!;
                    final blur = 16.0 + 14.0 * v;
                    final spread = 2.5 + 9.0 * v;
                    final scale = 1.0 + 0.1 * v;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: AiAssistantFabButton.fabSize * 0.72,
                        height: AiAssistantFabButton.fabSize * 0.72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          boxShadow: [
                            BoxShadow(
                              color: coreGlow,
                              blurRadius: blur,
                              spreadRadius: spread,
                            ),
                            BoxShadow(
                              color: outerGlow,
                              blurRadius: blur * 1.45,
                              spreadRadius: spread * 0.45,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/ai-assistant'),
                  customBorder: const CircleBorder(),
                  child: Image.asset(
                    AiAssistantFabButton.assetPath,
                    width: AiAssistantFabButton.fabSize,
                    height: AiAssistantFabButton.fabSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(
                        color: FlownetColors.crimsonRed,
                        child: SizedBox(
                          width: AiAssistantFabButton.fabSize,
                          height: AiAssistantFabButton.fabSize,
                          child: Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
