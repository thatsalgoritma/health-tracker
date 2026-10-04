import { plainToInstance } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsString,
  Min,
  MinLength,
  validateSync,
} from 'class-validator';

class EnvironmentVariables {
  @IsIn(['development', 'test', 'production'])
  NODE_ENV!: string;

  @IsInt()
  @Min(1)
  PORT!: number;

  @IsString()
  DATABASE_URL!: string;

  @IsString()
  @MinLength(32)
  JWT_SECRET!: string;
}

export function validateEnvironment(config: Record<string, unknown>) {
  const values = plainToInstance(EnvironmentVariables, {
    ...config,
    PORT: Number(config.PORT ?? 3000),
    NODE_ENV: config.NODE_ENV ?? 'development',
  });
  const errors = validateSync(values, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(
      `Invalid environment configuration: ${errors.map((error) => error.property).join(', ')}`,
    );
  }
  return values;
}
