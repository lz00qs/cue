import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class SetupDto {
  @ApiProperty({ example: 'admin@cue.local' })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ minLength: 8, maxLength: 72 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;
}

export class LoginDto {
  @ApiProperty({ example: 'admin@cue.local' })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ minLength: 8, maxLength: 1024 })
  @IsString()
  @MinLength(8)
  @MaxLength(1024)
  password!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MaxLength(4096)
  refreshToken!: string;
}

export class UpdateAccountDto {
  @ApiProperty({ minLength: 8, maxLength: 1024 })
  @IsString()
  @MinLength(8)
  @MaxLength(1024)
  currentPassword!: string;

  @ApiProperty({ example: 'admin@cue.local', required: false })
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string;

  @ApiProperty({ minLength: 8, maxLength: 72, required: false })
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword?: string;
}
