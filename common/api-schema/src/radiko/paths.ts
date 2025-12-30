export const RADIKO_PATHS = {
  AUTH: "/radiko/auth",
  STATIONS: "/radiko/stations/{area}",
} as const;

export type RadikoPaths = typeof RADIKO_PATHS;
