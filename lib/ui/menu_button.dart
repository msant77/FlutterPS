import 'package:flutter/material.dart';

/// Reusable styled button for menu screens.
class MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const MenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: _hovering
                ? (widget.primary
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.15))
                : (widget.primary
                    ? Colors.redAccent.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.primary
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.2),
              width: _hovering ? 2 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
