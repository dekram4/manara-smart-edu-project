export type StickerKey = 'star' | 'trophy' | 'badge' | 'spark';

const stickerRegistry: Record<StickerKey, string> = {
  star: '/stickers/star.svg',
  trophy: '/stickers/trophy.svg',
  badge: '/stickers/badge.svg',
  spark: '/stickers/spark.svg',
};

export const getStickerAsset = (key: string) => stickerRegistry[key as StickerKey] || stickerRegistry.badge;

export const stickerCatalog = Object.entries(stickerRegistry).map(([key, path]) => ({
  key,
  path,
}));
