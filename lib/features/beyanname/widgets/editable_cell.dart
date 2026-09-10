import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    // Arka plan:
    // Odaklanmışsa: Beyaz
    // Girilmişse (Dolu): Yumuşak pastel nane yeşili (#F0FDF4)
    // Girilmemişse (Boş / 0): Dikkat çeken sıcak sarı/kehribar (#FFFBEB)
    final Color bgColor = _focusNode.hasFocus
        ? Colors.white
        : (_isHovered
            ? (isFilled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7))
            : (isFilled ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB)));

    // Kenarlık:
    // Odaklanmışsa: Canlı Excel Mavisi (#2563EB)
    // Girilmişse (Dolu): Sakin yeşil kenarlık (#86EFAC)
    // Girilmemişse (Boş): Yumuşak sarı kenarlık (#FDE68A)
    final Color borderColor = _focusNode.hasFocus
        ? const Color(0xFF2563EB)
        : (_isHovered
            ? (isFilled ? const Color(0xFF4ADE80) : const Color(0xFFF59E0B))
            : (isFilled ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
              fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
              color: isFilled ? const Color(0xFF166534) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hintText,
              hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
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
