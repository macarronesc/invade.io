import type { ImageMetadata } from 'astro';
import heroEn from '../../../docs/store_assets/tablet_en/2_invasions.png';
import heroEs from '../../../docs/store_assets/tablet_es/2_invasions.png';
import atlasEn from '../../../docs/store_assets/tablet_en/4_atlas.png';
import atlasEs from '../../../docs/store_assets/tablet_es/4_atlas.png';
import graphics from '../../../docs/store_listing/graphics.json';

export type Language = 'en' | 'es';
const phones = import.meta.glob<ImageMetadata>('../../../docs/store_assets/screenshots_{en,es}/*.png', { eager: true, import: 'default' });
const scenes = ['conquer', 'tactics', 'invasions', 'campaign', 'daily', 'upgrades', 'cosmetics', 'atlas'] as const;

export function media(lang: Language) {
  return {
    hero: lang === 'es' ? heroEs : heroEn,
    atlas: lang === 'es' ? atlasEs : atlasEn,
    gallery: scenes.map((scene, index) => ({
      ...graphics[lang][scene],
      image: phones[`../../../docs/store_assets/screenshots_${lang}/${index + 1}_${scene}.png`],
    })),
  };
}
