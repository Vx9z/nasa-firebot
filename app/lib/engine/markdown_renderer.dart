import 'package:markdown/markdown.dart' as md;

/// Block-level kind of a rendered markdown line.
enum MdBlock {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  quote,
  listItem,
  codeBlock,
  rule,
  image,
}

/// A single inline run of styled text.
class MdSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool link;
  final String? href; // link destination (note://…, http(s)://…, or image src)
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.link = false,
    this.href,
  });
}

/// A rendered markdown line: a block kind plus its inline spans.
class MdLine {
  final MdBlock block;
  final List<MdSpan> spans;
  final String marker; // list bullet / number, or image alt text
  final String? imageUrl; // for MdBlock.image
  const MdLine(this.block, this.spans, {this.marker = '', this.imageUrl});
}

/// Parse markdown into styled CRT lines (headings, bold/italic, lists, links,
/// blockquotes, code blocks and horizontal rules) using the `markdown` package.
List<MdLine> renderMarkdown(String source) {
  if (source.trim().isEmpty) {
    return const [MdLine(MdBlock.paragraph, [MdSpan('(empty)')])];
  }
  // Obsidian-style embeds + wikilinks → markdown syntax, so they render as
  // images / links (instead of raw `![[…]]` / `[[…]]`).
  source = source
      .replaceAllMapped(
        RegExp(r'!\[\[([^\[\]]+)\]\]'),
        (m) => '![${m.group(1)}](${m.group(1)})',
      )
      .replaceAllMapped(
        RegExp(r'\[\[([^\[\]]+)\]\]'),
        (m) => '[${m.group(1)}](note://${Uri.encodeComponent(m.group(1)!)})',
      );
  final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
  final nodes = doc.parse(source);
  final out = <MdLine>[];
  for (final node in nodes) {
    _block(out, node);
  }
  return out.isEmpty ? const [MdLine(MdBlock.paragraph, [MdSpan('(empty)')])] : out;
}

void _block(List<MdLine> out, md.Node node) {
  if (node is md.Text) {
    final t = node.text.trim();
    if (t.isNotEmpty) out.add(MdLine(MdBlock.paragraph, [MdSpan(t)]));
    return;
  }
  if (node is! md.Element) {
    final t = node.textContent.trim();
    if (t.isNotEmpty) out.add(MdLine(MdBlock.paragraph, [MdSpan(t)]));
    return;
  }
  final children = node.children ?? const <md.Node>[];
  switch (node.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      out.add(MdLine(_heading(int.parse(node.tag.substring(1))), _inline(node)));
      break;
    case 'p':
      if (_isImageParagraph(node)) {
        final img = (node.children ?? const <md.Node>[]).first as md.Element;
        out.add(MdLine(
          MdBlock.image,
          const [],
          marker: img.attributes['alt'] ?? '',
          imageUrl: img.attributes['src'] ?? '',
        ));
      } else {
        final spans = _inline(node);
        if (spans.isNotEmpty) out.add(MdLine(MdBlock.paragraph, spans));
      }
      break;
    case 'blockquote':
      _quote(out, node);
      break;
    case 'ul':
      for (final c in children) {
        if (c is md.Element && c.tag == 'li') _listItem(out, c, '•');
      }
      break;
    case 'ol':
      var i = 1;
      for (final c in children) {
        if (c is md.Element && c.tag == 'li') {
          _listItem(out, c, '$i.');
          i++;
        }
      }
      break;
    case 'pre':
      for (final c in children) {
        final lines = c.textContent.split('\n');
        if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
        for (final l in lines) {
          out.add(MdLine(MdBlock.codeBlock, [MdSpan(l, code: true)]));
        }
      }
      break;
    case 'hr':
      out.add(const MdLine(MdBlock.rule, []));
      break;
    case 'table':
      _table(out, node);
      break;
    default:
      for (final c in children) {
        _block(out, c);
      }
  }
}

MdBlock _heading(int level) {
  switch (level) {
    case 1:
      return MdBlock.heading1;
    case 2:
      return MdBlock.heading2;
    case 3:
      return MdBlock.heading3;
    case 4:
      return MdBlock.heading4;
    case 5:
      return MdBlock.heading5;
    default:
      return MdBlock.heading6;
  }
}

/// A paragraph consisting of a single `![alt](src)` image → an image line.
bool _isImageParagraph(md.Node node) {
  if (node is! md.Element || node.tag != 'p') return false;
  final children = node.children ?? const <md.Node>[];
  if (children.length != 1) return false;
  return children.first is md.Element && (children.first as md.Element).tag == 'img';
}

List<MdSpan> _inline(md.Node node) {
  final spans = <MdSpan>[];
  _inlineInto(spans, node, false, false, false, false);
  return spans;
}

void _inlineInto(
  List<MdSpan> out,
  md.Node node,
  bool bold,
  bool italic,
  bool code,
  bool link, [
  String? href,
]) {
  if (node is md.Text) {
    if (node.text.isNotEmpty) {
      out.add(MdSpan(node.text,
          bold: bold, italic: italic, code: code, link: link, href: href));
    }
    return;
  }
  if (node is! md.Element) {
    final t = node.textContent;
    if (t.isNotEmpty) {
      out.add(MdSpan(t, bold: bold, italic: italic, code: code, link: link, href: href));
    }
    return;
  }
  final children = node.children ?? const <md.Node>[];
  switch (node.tag) {
    case 'strong':
    case 'b':
      for (final c in children) {
        _inlineInto(out, c, true, italic, code, link, href);
      }
      break;
    case 'em':
    case 'i':
      for (final c in children) {
        _inlineInto(out, c, bold, true, code, link, href);
      }
      break;
    case 'code':
      final t = node.textContent;
      if (t.isNotEmpty) {
        out.add(MdSpan(t, bold: bold, italic: italic, code: true, link: link, href: href));
      }
      break;
    case 'a':
      final h = node.attributes['href'] ?? '';
      for (final c in children) {
        _inlineInto(out, c, bold, italic, code, true, h);
      }
      break;
    case 'img':
      final alt = node.attributes['alt'] ?? '';
      if (alt.isNotEmpty) {
        out.add(MdSpan('[$alt]',
            bold: bold, italic: italic, code: code, link: true, href: node.attributes['src']));
      }
      break;
    case 'br':
      out.add(MdSpan(' ', bold: bold, italic: italic, code: code, link: link, href: href));
      break;
    case 'del':
    case 's':
    case 'strike':
      for (final c in children) {
        _inlineInto(out, c, bold, italic, code, link, href);
      }
      break;
    default:
      for (final c in children) {
        _inlineInto(out, c, bold, italic, code, link, href);
      }
  }
}

void _quote(List<MdLine> out, md.Node node) {
  if (node is! md.Element) {
    final t = node.textContent.trim();
    if (t.isNotEmpty) out.add(MdLine(MdBlock.quote, [MdSpan(t)]));
    return;
  }
  for (final c in node.children ?? const <md.Node>[]) {
    if (c is md.Element && c.tag == 'p') {
      final spans = _inline(c);
      if (spans.isNotEmpty) out.add(MdLine(MdBlock.quote, spans));
    } else if (c is md.Element) {
      _quote(out, c);
    } else {
      final t = c.textContent.trim();
      if (t.isNotEmpty) out.add(MdLine(MdBlock.quote, [MdSpan(t)]));
    }
  }
}

void _listItem(List<MdLine> out, md.Element li, String marker) {
  final spans = <MdSpan>[];
  final nested = <md.Node>[];
  for (final c in li.children ?? const <md.Node>[]) {
    if (c is md.Element && (c.tag == 'ul' || c.tag == 'ol')) {
      nested.add(c);
    } else {
      _inlineInto(spans, c, false, false, false, false);
    }
  }
  if (spans.isNotEmpty) out.add(MdLine(MdBlock.listItem, spans, marker: marker));
  for (final n in nested) {
    _block(out, n);
  }
}

void _table(List<MdLine> out, md.Element table) {
  for (final child in table.children ?? const <md.Node>[]) {
    _tableRows(out, child);
  }
}

void _tableRows(List<MdLine> out, md.Node node) {
  if (node is md.Element && node.tag == 'tr') {
    final cells = <String>[];
    for (final c in node.children ?? const <md.Node>[]) {
      if (c is md.Element && (c.tag == 'th' || c.tag == 'td')) {
        cells.add(c.textContent.trim());
      }
    }
    if (cells.isNotEmpty) {
      out.add(MdLine(MdBlock.paragraph, [MdSpan(cells.join(' | '))]));
    }
    return;
  }
  if (node is! md.Element) return;
  for (final c in node.children ?? const <md.Node>[]) {
    _tableRows(out, c);
  }
}

