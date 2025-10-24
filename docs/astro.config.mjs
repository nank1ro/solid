// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      title: 'Flutter Solid Framework',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/nank1ro/solid' }],
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
