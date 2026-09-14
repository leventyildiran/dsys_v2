import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// Excel/Google Sheets stili, sıfır donma garantili, yerel odaklı giriş hücresi.
/// Her tuş vuruşunda üst widget ağacını yeniden çizmez (rebuild yapmaz).
/// Sadece kullanıcı Enter'a bastığında veya hücreden çıktığında (onFocusChange)
/// tek bir sefer tetiklenir.
class EditableCell extends StatefulWidget {
  final double value;
  final ValueChanged<double> onSubmitted;
  final String hintText;
  final bool isBold;
  final Color? textColor;
  final TextAlign textAlign;
  final double height;
  final double fontSize;

  const EditableCell({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.hintText = '0,00',
    this.isBold = false,
    this.textColor,
    this.textAlign = TextAlign.right,
    this.height = 28,
    this.fontSize = 11,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sadece odak dışındayken ve dışarıdan değer değiştiyse güncelle
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitValue();
    }
  }

  void _commitValue() {
    final text = _controller.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final parsed = double.tryParse(text) ?? 0.0;
    if (parsed != widget.value) {
      widget.onSubmitted(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFilled = widget.value > 0;

    // Excel/Google Sheets stili: Boş ve dolu hücreler tablo satırıyla kusursuz bütünleşir.
    // Odaklanıldığında temiz mavi çerçeve belirir, hover edildiğinde hafif ton değişir.
    final Color bgColor = _focusNode.hasFocus
        ? AppColors.surface
        : (_isHovered ? AppColors.surfaceVariant.withValues(alpha: 0.5) : AppColors.transparent);

    final Color borderColor = _focusNode.hasFocus
        ? AppColors.primary
        : (_isHovered ? AppColors.borderStrong : AppColors.transparent);

    final String displayHint = widget.hintText;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor,
            width: _focusNode.hasFocus ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: widget.textAlign,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: isFilled ? (widget.isBold ? FontWeight.bold : FontWeight.w600) : (widget.isBold ? FontWeight.bold : FontWeight.normal),
              color: isFilled
                  ? (widget.textColor ?? const Color(0xFF0F172A))
                  : (widget.textColor ?? AppColors.textMuted),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: displayHint,
              hintStyle: TextStyle(
                fontSize: widget.fontSize,
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontWeight: FontWeight.normal,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onSubmitted: (_) {
              _commitValue();
              _focusNode.unfocus();
            },
          ),
        ),
      ),
    );
  }
}
