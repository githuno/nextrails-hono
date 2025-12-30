import { z } from 'zod';

// 基本的なスキーマ定義
export const StationSchema = z.object({
  id: z.string(),
  name: z.string(),
  url: z.string().optional(),
  banner: z.string().optional(),
});

export const StationsResponseSchema = z.object({
  data: z.array(StationSchema),
});

// レスポンス型の定義
export type Station = z.infer<typeof StationSchema>;
export type StationsResponse = z.infer<typeof StationsResponseSchema>;