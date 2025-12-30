import { z } from "zod";
import type { ApiPath, ApiResponse, ExtractHttpMethod } from "./type-utils";
import { AuthResponseSchema } from "./radiko/zod/auth";
import { StationsResponseSchema } from "./radiko/zod/stations";
import { RADIKO_PATHS } from "./radiko/paths";

const SCHEMA_MAP = {
  [RADIKO_PATHS.AUTH]: {
    post: AuthResponseSchema,
  },
  [RADIKO_PATHS.STATIONS]: {
    get: StationsResponseSchema,
  },
} as const;

export const createResponseSchema = <
  Path extends ApiPath,
  Method extends ExtractHttpMethod<Path>
>(
  path: Path,
  method: Method
): z.ZodType<ApiResponse<Path, Method>> => {
  const schemas = SCHEMA_MAP[path as keyof typeof SCHEMA_MAP];
  if (!schemas) {
    throw new Error(`Undefined schema path: ${path}`);
  }

  const schema = schemas[method as keyof typeof schemas];
  if (!schema) {
    throw new Error(`Undefined schema method: ${method} for path ${path}`);
  }

  return schema as unknown as z.ZodType<ApiResponse<Path, Method>>;
};
