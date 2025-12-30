import { z } from 'zod';

export const AuthResponseSchema = z.object({
  token: z.string(),
  areaId: z.string(),
  success: z.boolean().optional(),
  timestamp: z.number().optional(),
});

// レスポンス型の定義
export type AuthResponse = z.infer<typeof AuthResponseSchema>;