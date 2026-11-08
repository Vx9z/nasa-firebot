import 'package:flutter_test/flutter_test.dart';

import 'package:app/engine/markdown_renderer.dart';

void main() {
  test('renders headings with the right block kind', () {
    final lines = renderMarkdown('# Title\n## Sub\nBody **bold** and *ital*');
    expect(lines[0].block, MdBlock.heading1);
    expect(lines[1].block, MdBlock.heading2);
  });

  test('parses inline bold, italic, code and links', () {
    final lines = renderMarkdown('A **b** *i* `c` [link](url)');
    final spans = lines.first.spans;
    final bold = spans.firstWhere((s) => s.text == 'b');
    expect(bold.bold, isTrue);
    final ital = spans.firstWhere((s) => s.text == 'i');
    expect(ital.italic, isTrue);
    final code = spans.firstWhere((s) => s.text == 'c');
    expect(code.code, isTrue);
    final link = spans.firstWhere((s) => s.text == 'link');
    expect(link.link, isTrue);
  });

  test('renders unordered and ordered lists with markers', () {
    final lines = renderMarkdown('- a\n- b\n1. one\n2. two');
    expect(lines[0].marker, '•');
    expect(lines[1].marker, '•');
    expect(lines[2].marker, '1.');
    expect(lines[3].marker, '2.');
  });

  test('renders code blocks and quotes', () {
    final lines = renderMarkdown('```\nx = 1\n```\n\n> quoted');
    expect(lines.any((l) => l.block == MdBlock.codeBlock), isTrue);
    expect(lines.last.block, MdBlock.quote);
  });

  test('empty markdown falls back to a placeholder', () {
    final lines = renderMarkdown('   ');
    expect(lines.single.spans.single.text, '(empty)');
  });

  test('wikilinks [[page]] render as links, not raw brackets', () {
    final lines = renderMarkdown('See [[Combustion Basics]] here');
    final spans = lines.first.spans;
    final link = spans.firstWhere((s) => s.link && s.text == 'Combustion Basics');
    expect(link.link, isTrue);
  });

  test('![alt](url) renders as an image block', () {
    final lines = renderMarkdown('![diagram](http://x/a.png)');
    expect(lines.single.block, MdBlock.image);
    expect(lines.single.imageUrl, 'http://x/a.png');
    expect(lines.single.marker, 'diagram');
  });

  test('obsidian embed ![[file.png]] renders as an image', () {
    final lines = renderMarkdown('![[flame.png]]');
    expect(lines.single.block, MdBlock.image);
    expect(lines.single.imageUrl, 'flame.png');
  });
}
