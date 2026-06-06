import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import '../../../core/theme/app_theme.dart';

class OnlineWordEditor extends StatefulWidget {
  final String initialHtmlOrText;
  final ValueChanged<String> onChange;

  const OnlineWordEditor({
    super.key,
    required this.initialHtmlOrText,
    required this.onChange,
  });

  @override
  State<OnlineWordEditor> createState() => _OnlineWordEditorState();
}

class _OnlineWordEditorState extends State<OnlineWordEditor> {
  late quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    
    // Eğer gelen metin HTML ise (<table> vb. içeriyorsa) bunu Delta'ya çevir
    // Yoksa düz metin olarak ekle
    quill.Document doc;
    try {
      if (widget.initialHtmlOrText.contains('<') && widget.initialHtmlOrText.contains('>')) {
        final delta = HtmlToDelta().convert(widget.initialHtmlOrText);
        doc = quill.Document.fromDelta(delta);
      } else {
        doc = quill.Document()..insert(0, widget.initialHtmlOrText);
      }
    } catch (e) {
      debugPrint('HTML to Delta hatası: $e');
      doc = quill.Document()..insert(0, widget.initialHtmlOrText);
    }

    _controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _controller.addListener(() {
      final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
      widget.onChange(deltaJson);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Word benzeri Toolbar (Üst Bar)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showCodeBlock: false,
                showInlineCode: false,
                showLink: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
              ),
            ),
          ),
          
          // Yazı Alanı (A4 Kağıdı Görünümü)
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  width: 800, // A4 genişliği simülasyonu
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: quill.QuillEditor.basic(
                    controller: _controller,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
