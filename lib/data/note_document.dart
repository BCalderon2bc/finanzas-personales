/// Rich-text runs use UTF-16 offsets, matching Flutter's text selections.
class NoteStyle {
  const NoteStyle({this.bold = false, this.color, this.size = 16});
  final bool bold;
  final int? color;
  final double size;
  NoteStyle copyWith({
    bool? bold,
    int? color,
    bool clearColor = false,
    double? size,
  }) => NoteStyle(
    bold: bold ?? this.bold,
    color: clearColor ? null : color ?? this.color,
    size: size ?? this.size,
  );
  @override
  bool operator ==(Object other) =>
      other is NoteStyle &&
      bold == other.bold &&
      color == other.color &&
      size == other.size;
  @override
  int get hashCode => Object.hash(bold, color, size);
}

class NoteDocument {
  String text = '';
  List<NoteStyle> styles = [];
  void load(String value, Object? raw) {
    text = value;
    styles = List.filled(text.length, const NoteStyle(), growable: true);
    if (raw is! List) return;
    for (final run in raw) {
      if (run is! Map) continue;
      final start = run['start'], length = run['length'];
      if (start is! int ||
          length is! int ||
          start < 0 ||
          length < 1 ||
          start + length > text.length)
        continue;
      final color = run['color'];
      final size = run['size'];
      final style = NoteStyle(
        bold: run['bold'] == true,
        color: color is int && color >= 0 && color <= 0xffffffff ? color : null,
        size: size is num && [14, 16, 18, 20, 24, 28, 32].contains(size)
            ? size.toDouble()
            : 16,
      );
      styles.fillRange(start, start + length, style);
    }
  }

  void replace(
    String next,
    NoteStyle insertionStyle, {
    int? selectionStart,
    int? selectionEnd,
    int? caret,
  }) {
    bool replaceAt(int start, int end) {
      final inserted = next.length - text.length + end - start;
      if (start < 0 ||
          end < start ||
          end > text.length ||
          inserted < 0 ||
          start + inserted > next.length)
        return false;
      if (next.substring(0, start) != text.substring(0, start) ||
          next.substring(start + inserted) != text.substring(end))
        return false;
      styles.replaceRange(start, end, List.filled(inserted, insertionStyle));
      text = next;
      return true;
    }

    if (selectionStart != null &&
        selectionEnd != null &&
        replaceAt(selectionStart, selectionEnd))
      return;
    if (caret != null &&
        next.length < text.length &&
        replaceAt(caret, caret + text.length - next.length))
      return;

    var start = 0;
    while (start < text.length &&
        start < next.length &&
        text.codeUnitAt(start) == next.codeUnitAt(start)) {
      start++;
    }
    var oldEnd = text.length, newEnd = next.length;
    while (oldEnd > start &&
        newEnd > start &&
        text.codeUnitAt(oldEnd - 1) == next.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    styles.replaceRange(
      start,
      oldEnd,
      List.filled(newEnd - start, insertionStyle),
    );
    text = next;
  }

  void format(int start, int end, NoteStyle Function(NoteStyle) change) {
    if (start < 0 || end > styles.length || start >= end) return;
    for (var i = start; i < end; i++) {
      styles[i] = change(styles[i]);
    }
  }

  List<Map<String, dynamic>> toJson() {
    final result = <Map<String, dynamic>>[];
    for (var start = 0; start < styles.length;) {
      var end = start + 1;
      final style = styles[start];
      while (end < styles.length && styles[end] == style) {
        end++;
      }
      if (style != const NoteStyle()) {
        result.add({
          'start': start,
          'length': end - start,
          'bold': style.bold,
          if (style.color != null) 'color': style.color,
          'size': style.size,
        });
      }
      start = end;
    }
    return result;
  }
}
