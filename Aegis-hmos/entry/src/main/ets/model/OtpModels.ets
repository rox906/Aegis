// OTP Type identifiers
export enum OtpType {
  TOTP = 'totp',
  HOTP = 'hotp',
  STEAM = 'steam',
  MOTP = 'motp',
  YANDEX = 'yandex'
}

// Supported hash algorithms
export enum OtpAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512',
  MD5 = 'MD5'
}

// Base OTP info interface
export interface OtpInfo {
  type: OtpType;
  secret: Uint8Array;
  algorithm: OtpAlgorithm;
  digits: number;
}

// TOTP-specific info
export interface TotpInfo extends OtpInfo {
  type: OtpType.TOTP;
  period: number;
}

// HOTP-specific info
export interface HotpInfo extends OtpInfo {
  type: OtpType.HOTP;
  counter: number;
}

// Steam-specific info (TOTP variant with custom alphabet)
export interface SteamInfo extends OtpInfo {
  type: OtpType.STEAM;
  period: number;
}

// mOTP-specific info
export interface MotpInfo extends OtpInfo {
  type: OtpType.MOTP;
  period: number;
  pin: string;
}

// Yandex-specific info
export interface YandexInfo extends OtpInfo {
  type: OtpType.YANDEX;
  period: number;
  pin: string;
}

// Union type for all OTP info variants
export type AnyOtpInfo = TotpInfo | HotpInfo | SteamInfo | MotpInfo | YandexInfo;

// OTP defaults
export const OTP_DEFAULT_DIGITS: number = 6;
export const OTP_DEFAULT_ALGORITHM: OtpAlgorithm = OtpAlgorithm.SHA1;
export const TOTP_DEFAULT_PERIOD: number = 30;
export const HOTP_DEFAULT_COUNTER: number = 0;
export const STEAM_DEFAULT_DIGITS: number = 5;

// Helper to get period from any TOTP-like OTP
export function getOtpPeriod(info: AnyOtpInfo): number {
  if (info.type === OtpType.TOTP || info.type === OtpType.STEAM ||
    info.type === OtpType.MOTP || info.type === OtpType.YANDEX) {
    return (info as TotpInfo).period;
  }
  return 0;
}

// Check if OTP type is time-based
export function isTimeBased(info: AnyOtpInfo): boolean {
  return info.type !== OtpType.HOTP;
}
