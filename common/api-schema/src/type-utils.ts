import type { Get } from 'type-fest';
import type { paths } from '../outputs/schema';

export type ApiPath = keyof paths;

export type ExtractHttpMethod<Path extends ApiPath> = Extract<keyof paths[Path], string>;

export type SuccessCode = 200 | 201;

export type ExtractStatusCode<
  Path extends ApiPath,
  Method extends ExtractHttpMethod<Path>
> = keyof (paths[Path][Method] extends { responses: unknown } ? paths[Path][Method]['responses'] : never);

export type ExtractResponseType = 'application/json';

export type ApiResponse<
  Path extends ApiPath,
  Method extends ExtractHttpMethod<Path>
> = Get<
  paths,
  [
    Extract<Path, string>,
    Extract<Method, string>,
    'responses',
    Extract<ExtractStatusCode<Path, Method>, SuccessCode> & string,
    'content',
    ExtractResponseType
  ]
>;