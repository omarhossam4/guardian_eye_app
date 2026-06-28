import 'package:flutter/material.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';

/// Premium primary button with gradient fill and tasteful shadow.
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;
  final double height;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.height = 56,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.isLoading || widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: _isDisabled ? null : (_) => _pressCtrl.reverse(),
      onTapCancel: _isDisabled ? null : () => _pressCtrl.reverse(),
      onTap: _isDisabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height,
          child: widget.isOutlined ? _buildOutlined() : _buildFilled(),
        ),
      ),
    );
  }

  Widget _buildFilled() {
    final radius = BorderRadius.circular(widget.height < 44 ? 12 : 16);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isDisabled ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: _isDisabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF2D9CDB), Color(0xFF1C7FC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isDisabled ? AppColors.primary.withValues(alpha: 0.55) : null,
          borderRadius: radius,
          boxShadow: _isDisabled ? null : AppColors.buttonShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: _isDisabled ? null : widget.onPressed,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Center(child: _buildContent(false)),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlined() {
    final radius = BorderRadius.circular(widget.height < 44 ? 12 : 16);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: radius,
        border: Border.all(
          color: _isDisabled ? AppColors.border : AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: _isDisabled ? null : widget.onPressed,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Center(child: _buildContent(true)),
        ),
      ),
    );
  }

  Widget _buildContent(bool outlined) {
    if (widget.isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            outlined ? AppColors.primary : Colors.white,
          ),
        ),
      );
    }

    final color = outlined ? AppColors.primary : Colors.white;
    final fontSize = widget.height < 44 ? 14.0 : null;

    Widget label = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.button.copyWith(
        color: color,
        fontSize: fontSize,
      ),
    );

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon,
            size: widget.height < 44 ? 16 : 18,
            color: color,
          ),
          SizedBox(width: widget.height < 44 ? 6 : 8),
          Flexible(child: label),
        ],
      );
    }

    return label;
  }
}
