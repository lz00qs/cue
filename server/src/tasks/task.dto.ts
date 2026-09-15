import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

export class CreateTaskDto {
  @ApiProperty({ maxLength: 240 })
  @IsString()
  @Length(1, 240)
  title!: string;

  @ApiPropertyOptional({ maxLength: 5000 })
  @IsOptional()
  @IsString()
  @Length(0, 5000)
  note?: string;

  @ApiPropertyOptional({ enum: ['todo', 'doing', 'done'] })
  @IsOptional()
  @IsIn(['todo', 'doing', 'done'])
  status?: 'todo' | 'doing' | 'done';

  @ApiPropertyOptional({ minimum: 0, maximum: 3 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3)
  priority?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  important?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  sortOrder?: number;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsDateString()
  dueAt?: string | null;
}

export class UpdateTaskDto {
  @ApiProperty({ description: 'Optimistic concurrency version' })
  @IsInt()
  @Min(1)
  version!: number;

  @ApiPropertyOptional({ maxLength: 240 })
  @IsOptional()
  @IsString()
  @Length(1, 240)
  title?: string;

  @ApiPropertyOptional({ maxLength: 5000 })
  @IsOptional()
  @IsString()
  @Length(0, 5000)
  note?: string;

  @ApiPropertyOptional({ enum: ['todo', 'doing', 'done'] })
  @IsOptional()
  @IsIn(['todo', 'doing', 'done'])
  status?: 'todo' | 'doing' | 'done';

  @ApiPropertyOptional({ minimum: 0, maximum: 3 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3)
  priority?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  important?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  sortOrder?: number;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  dueAt?: string | null;
}

export class DeleteTaskDto {
  @ApiProperty({ description: 'Optimistic concurrency version' })
  @IsInt()
  @Min(1)
  version!: number;
}
