// Gera o JSON-LD de perguntas frequentes (schema.org FAQPage) a partir das
// perguntas da própria página, para os dois nunca ficarem diferentes.
// Uso: node scripts/site-seo.mjs dist/index.html
import { readFileSync, writeFileSync } from 'node:fs';

const file = process.argv[2];
const html = readFileSync(file, 'utf8');
const marker = /<!-- faq-jsonld:[^>]*-->/;
const strip = (s) => s.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();

const faq = [...html.matchAll(/<details>\s*<summary>([\s\S]*?)<\/summary>\s*<p>([\s\S]*?)<\/p>\s*<\/details>/g)]
  .map(([, q, a]) => ({
    '@type': 'Question',
    name: strip(q),
    acceptedAnswer: { '@type': 'Answer', text: strip(a) },
  }));
if (!marker.test(html) || faq.length === 0) {
  console.error('site-seo: marcador ou perguntas não encontrados.');
  process.exit(1);
}
const json = JSON.stringify({ '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: faq });
writeFileSync(file, html.replace(marker, `<script type="application/ld+json">${json.replace(/</g, '\u003c')}</script>`));
console.log(`site-seo: ${faq.length} perguntas no JSON-LD.`);
