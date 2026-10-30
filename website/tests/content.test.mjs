import test from 'node:test';
import assert from 'node:assert/strict';
import { guideContent, resolveLink, transformTree } from '../scripts/content.mjs';
import { guides } from '../scripts/site.mjs';

test('canonical guides have unique sources and routes', () => {
  assert.equal(new Set(guides.map(([source]) => source)).size, guides.length);
  assert.equal(new Set(guides.map(([, slug]) => slug)).size, guides.length);
});

test('links preserve anchors, route guides internally, and pin code to the source commit', () => {
  assert.equal(resolveLink('DEVELOPMENT.md#localization', 'docs/README.md', 'abc'), '/invade.io/docs/development/#localization');
  assert.equal(resolveLink('../CONTRIBUTING.md', 'docs/README.md', 'abc'), '/invade.io/docs/contributing/');
  assert.equal(resolveLink('../scripts/ui/', 'docs/ARCHITECTURE.md', 'abc'), 'https://github.com/macarronesc/invade.io/tree/abc/scripts/ui/');
  assert.equal(resolveLink('../project.godot', 'docs/README.md', 'abc'), 'https://github.com/macarronesc/invade.io/blob/abc/project.godot');
  for (const url of ['#localization', 'https://example.com/a#b', 'mailto:test@example.com']) {
    assert.equal(resolveLink(url, 'docs/README.md', 'abc'), url);
  }
  assert.throws(() => resolveLink('../../secret', 'docs/README.md', 'abc'));
  assert.throws(() => resolveLink('javascript:alert(1)', 'docs/README.md', 'abc'));
});

test('adaptation removes only the source title, not code or prose', () => {
  const text = '# A guide\n\n## Run\n\n```sh\ncat README.md\n```\n';
  const output = guideContent(text, 'docs/README.md', 'abcdef123', '0.3.1');
  assert.match(output, /title: "A guide"/);
  assert.match(output, /edit\/dev\/docs\/README.md/);
  assert.ok(output.endsWith(text.slice('# A guide\n'.length)));
  assert.throws(() => guideContent('No title', 'docs/README.md', 'abc', '1'));
  assert.match(guideContent(text, 'docs/README.md', 'abc', '1', true), /uncommitted/);
});

test('Markdown transforms nested links and diagrams, but never command examples', () => {
  const code = { type: 'code', lang: 'sh', value: 'cat ../README.md' };
  const link = { type: 'link', url: '../README.md' };
  const diagram = { type: 'code', lang: 'mermaid', value: 'graph TD\n A[Menu] --> B[Battle]' };
  transformTree({ children: [{ children: [code, link, diagram] }] }, 'docs/TESTING.md', 'abc');
  assert.equal(code.value, 'cat ../README.md');
  assert.equal(link.url, '/invade.io/');
  assert.match(diagram.value, /<svg role="img"/);
  assert.match(diagram.value, /tabindex="0"/);
  assert.match(diagram.value, /Diagram source/);
  assert.throws(() => transformTree({ type: 'image', url: '../private.png' }, 'docs/README.md', 'abc'));
});
