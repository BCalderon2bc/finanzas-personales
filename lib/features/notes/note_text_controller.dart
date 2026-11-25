import 'package:flutter/material.dart';
import '../../data/note_document.dart';

class NoteTextController extends TextEditingController {
  final document = NoteDocument();
  NoteStyle insertionStyle = const NoteStyle();
  bool _loading = false;
  void load(String text, Object? format) {
    _loading = true;
    document.load(text, format);
    insertionStyle = document.styles.isEmpty
        ? const NoteStyle()
        : document.styles.last;
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _loading = false;
  }

  @override
  set value(TextEditingValue next) {
    if (!_loading) {
      if (next.text != text) {
        document.replace(
          next.text,
          insertionStyle,
          selectionStart: selection.isValid ? selection.start : null,
          selectionEnd: selection.isValid ? selection.end : null,
          caret: next.selection.isValid ? next.selection.start : null,
        );
      } else if (next.selection != selection &&
          next.selection.isValid &&
          document.styles.isNotEmpty) {
        final index = next.selection.isCollapsed
            ? next.selection.start - 1
            : next.selection.start;
        insertionStyle = index >= 0 && index < document.styles.length
            ? document.styles[index]
            : const NoteStyle();
      }
    }
    super.value = next;
  }

  NoteStyle get currentStyle {
    if (selection.isValid &&
        !selection.isCollapsed &&
        document.styles.isNotEmpty) {
      final i = selection.isCollapsed ? selection.start - 1 : selection.start;
      if (i >= 0 && i < document.styles.length) return document.styles[i];
    }
    return insertionStyle;
  }

  void apply(NoteStyle Function(NoteStyle) change) {
    insertionStyle = change(currentStyle);
    if (selection.isValid && !selection.isCollapsed) {
      document.format(selection.start, selection.end, change);
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <TextSpan>[];
    for (var start = 0; start < text.length;) {
      final run = document.styles[start];
      final composing =
          withComposing &&
          value.composing.isValid &&
          start >= value.composing.start &&
          start < value.composing.end;
      var end = start + 1;
      while (end < text.length &&
          document.styles[end] == run &&
          (!withComposing ||
              !value.composing.isValid ||
              (end >= value.composing.start && end < value.composing.end) ==
                  composing)) {
        end++;
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontWeight: run.bold ? FontWeight.w700 : FontWeight.w400,
            color: run.color == null ? null : Color(run.color!),
            fontSize: run.size,
            decoration: composing ? TextDecoration.underline : null,
          ),
        ),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
  }
}
