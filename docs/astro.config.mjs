// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLlmsTxt from 'starlight-llms-txt';

// https://astro.build/config
export default defineConfig({
  site: 'https://solid.mariuti.com',
  integrations: [
    starlight({
      title: 'Flutter Solid Framework',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/nank1ro/solid' }],
      head: [
        {
          tag: 'script',
          attrs: {
            defer: true,
            src: 'https://umami.mariuti.com/script.js',
            'data-website-id': '682aff24-32d8-48eb-b29a-a8ec596dc1e4',
          },
        },
      ],
      plugins: [
        starlightLlmsTxt({
          description:
            'Solid is a tiny Flutter framework that uses code generation and fine-grained reactivity (inspired by SwiftUI and SolidJS) to remove state-management and DI boilerplate. You write annotated widgets in source/; the generator emits runnable Flutter into lib/.',
        }),
      ],
      sidebar: [
        {
          label: '',
          link: 'https://pub.dev/packages/solid_generator',
          badge: { text: 'pub.dev', variant: 'tip' },
          attrs: { target: '_blank', rel: 'noopener noreferrer' },
        },
        {
          label: 'Guides',
          autogenerate: { directory: 'guides' },
        },
        { label: 'FAQ', link: 'faq' },
        { label: 'Author', link: 'author' },
      ],
    }),
  ],
});
