import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import {
  AnyOtpInfo,
  OtpType,
  OtpAlgorithm,
  TotpInfo,
  HotpInfo,
  SteamInfo,
  MotpInfo,
  YandexInfo
} from '../model/OtpModels';
import { Hex } from '../util/Encoding';

const STEAM_ALPHABET = '23456789BCDFGHJKMNPQRTVWXY';

// Map OtpAlgorithm to HarmonyOS Mac algorithm names
function getHmacAlgoName(algorithm: OtpAlgorithm): string {
  switch (algorithm) {
    case OtpAlgorithm.SHA1:
      return 'SHA1';
    case OtpAlgorithm.SHA256:
      return 'SHA256';
    case OtpAlgorithm.SHA512:
      return 'SHA512';
    case OtpAlgorithm.MD5:
      return 'MD5';
    default:
      return 'SHA1';
  }
}

function getDigestAlgoName(algorithm: OtpAlgorithm): string {
  switch (algorithm) {
    case OtpAlgorithm.MD5:
      return 'MD5';
    case OtpAlgorithm.SHA1:
      return 'SHA1';
    case OtpAlgorithm.SHA256:
      return 'SHA256';
    case OtpAlgorithm.SHA512:
      return 'SHA512';
    default:
      return 'MD5';
  }
}

// Convert a long (64-bit counter) to 8-byte big-endian Uint8Array
function longToBytes(value: number): Uint8Array {
  const bytes = new Uint8Array(8);
  // JavaScript numbers are 64-bit floats; counter values fit in 53-bit int
  let v = Math.floor(value);
  for (let i = 7; i >= 0; i--) {
    bytes[i] = v & 0xff;
    v = Math.floor(v / 256);
  }
  return bytes;
}

// HMAC computation using HarmonyOS CryptoArchitectureKit
async function computeHmac(secret: Uint8Array, data: Uint8Array, algo: OtpAlgorithm): Promise<Uint8Array> {
  const algoName = getHmacAlgoName(algo);
  const mac = cryptoFramework.createMac(`HMAC|${algoName}`);
  const symKeyBlob: cryptoFramework.DataBlob = { data: secret };
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator(`HMAC`);
  const symKey = await symKeyGenerator.convertKey(symKeyBlob);
  await mac.init(symKey);
  await mac.update({ data: data });
  const result = await mac.doFinal();
  return result.data;
}

// MD5/SHA digest
async function computeDigest(data: Uint8Array, algo: OtpAlgorithm): Promise<Uint8Array> {
  const algoName = getDigestAlgoName(algo);
  const md = cryptoFramework.createMd(algoName);
  await md.update({ data: data });
  const result = await md.digest();
  return result.data;
}

// HOTP generation (RFC 4226)
async function generateHotp(secret: Uint8Array, algo: OtpAlgorithm, digits: number,
  counter: number): Promise<number> {
  const counterBytes = longToBytes(counter);
  const hash = await computeHmac(secret, counterBytes, algo);

  // Dynamic truncation
  const offset = hash[hash.length - 1] & 0x0f;
  const otp = ((hash[offset] & 0x7f) << 24)
    | ((hash[offset + 1] & 0xff) << 16)
    | ((hash[offset + 2] & 0xff) << 8)
    | (hash[offset + 3] & 0xff);

  return otp;
}

// Format numeric OTP code with leading zeros
function formatOtpCode(code: number, digits: number): string {
  const truncated = code % Math.pow(10, digits);
  return truncated.toString().padStart(digits, '0');
}

// Format Steam code with custom alphabet
function formatSteamCode(code: number, digits: number): string {
  let c = code;
  let result = '';
  for (let i = 0; i < digits; i++) {
    result += STEAM_ALPHABET.charAt(c % STEAM_ALPHABET.length);
    c = Math.floor(c / STEAM_ALPHABET.length);
  }
  return result;
}

// Main OTP generation function
export class OtpService {
  // Generate OTP code for any OTP type
  static async generateCode(info: AnyOtpInfo): Promise<string> {
    if (info.secret.length === 0) {
      throw new Error('Secret is empty');
    }

    switch (info.type) {
      case OtpType.TOTP:
        return OtpService.generateTotp(info as TotpInfo);
      case OtpType.HOTP:
        return OtpService.generateHotpCode(info as HotpInfo);
      case OtpType.STEAM:
        return OtpService.generateSteam(info as SteamInfo);
      case OtpType.MOTP:
        return OtpService.generateMotp(info as MotpInfo);
      case OtpType.YANDEX:
        return OtpService.generateYandex(info as YandexInfo);
      default:
        throw new Error(`Unsupported OTP type`);
    }
  }

  // TOTP: time-based OTP
  static async generateTotp(info: TotpInfo, timeSeconds?: number): Promise<string> {
    const time = timeSeconds !== undefined ? timeSeconds : Math.floor(Date.now() / 1000);
    const counter = Math.floor(time / info.period);
    const otp = await generateHotp(info.secret, info.algorithm, info.digits, counter);
    return formatOtpCode(otp, info.digits);
  }

  // HOTP: counter-based OTP
  static async generateHotpCode(info: HotpInfo): Promise<string> {
    const otp = await generateHotp(info.secret, info.algorithm, info.digits, info.counter);
    return formatOtpCode(otp, info.digits);
  }

  // Steam Guard code
  static async generateSteam(info: SteamInfo, timeSeconds?: number): Promise<string> {
    const time = timeSeconds !== undefined ? timeSeconds : Math.floor(Date.now() / 1000);
    const counter = Math.floor(time / info.period);
    const otp = await generateHotp(info.secret, info.algorithm, info.digits, counter);
    return formatSteamCode(otp, info.digits);
  }

  // mOTP: Mobile OTP
  static async generateMotp(info: MotpInfo, timeSeconds?: number): Promise<string> {
    const time = timeSeconds !== undefined ? timeSeconds : Math.floor(Date.now() / 1000);
    const counter = Math.floor(time / info.period);
    const secretHex = Hex.encode(info.secret);
    const toDigest = `${counter}${secretHex}${info.pin}`;
    const encoder = new util.TextEncoder();
    const digestInput = encoder.encodeInto(toDigest);
    const hash = await computeDigest(new Uint8Array(digestInput), info.algorithm);
    const hashHex = Hex.encode(hash);
    return hashHex.substring(0, info.digits);
  }

  // Yandex OTP
  static async generateYandex(info: YandexInfo, timeSeconds?: number): Promise<string> {
    const time = timeSeconds !== undefined ? timeSeconds : Math.floor(Date.now() / 1000);
    const encoder = new util.TextEncoder();
    const pinBytes = encoder.encodeInto(info.pin);

    // Combine pin + secret
    const combined = new Uint8Array(pinBytes.length + info.secret.length);
    combined.set(new Uint8Array(pinBytes), 0);
    combined.set(info.secret, pinBytes.length);

    // SHA-256 digest
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: combined });
    const keyHashResult = await md.digest();
    let keyHash = keyHashResult.data;

    // Strip leading zero if present
    if (keyHash[0] === 0) {
      keyHash = keyHash.slice(1);
    }

    const counter = Math.floor(time / info.period);
    const counterBytes = longToBytes(counter);
    const hmacAlgo = info.algorithm === OtpAlgorithm.SHA1 ? OtpAlgorithm.SHA1 : info.algorithm;
    const periodHash = await computeHmac(keyHash, counterBytes, hmacAlgo);

    const offset = periodHash[periodHash.length - 1] & 0x0f;
    // Mask high bit at offset
    const masked = new Uint8Array(periodHash);
    masked[offset] = masked[offset] & 0x7f;

    // Read 8 bytes as big-endian long starting at offset
    let otp: number = 0;
    for (let i = 0; i < 8; i++) {
      otp = otp * 256 + masked[offset + i];
    }

    const EN_ALPHABET_LENGTH = 26;
    let code = otp % Math.pow(EN_ALPHABET_LENGTH, info.digits);
    const chars: string[] = [];
    for (let i = info.digits - 1; i >= 0; i--) {
      const charCode = 'a'.charCodeAt(0) + (code % EN_ALPHABET_LENGTH);
      chars[i] = String.fromCharCode(charCode);
      code = Math.floor(code / EN_ALPHABET_LENGTH);
    }
    return chars.join('');
  }

  // Get milliseconds until next TOTP rotation
  static getMillisTillNextRotation(period: number): number {
    const p = period * 1000;
    return p - (Date.now() % p);
  }

  // Get the current progress (0.0 to 1.0) for TOTP countdown
  static getTotpProgress(period: number): number {
    const p = period * 1000;
    const elapsed = Date.now() % p;
    return 1.0 - (elapsed / p);
  }

  // Format OTP code with grouping
  static formatCodeWithGrouping(code: string, groupSize: number): string {
    if (groupSize === -2) {
      // No grouping
      return code;
    }
    if (groupSize === -1) {
      // Halves
      const half = Math.ceil(code.length / 2);
      return `${code.substring(0, half)} ${code.substring(half)}`;
    }
    // Group by specified size
    const parts: string[] = [];
    for (let i = 0; i < code.length; i += groupSize) {
      parts.push(code.substring(i, Math.min(i + groupSize, code.length)));
    }
    return parts.join(' ');
  }
}

// Need to import util for TextEncoder
import { util } from '@kit.ArkTS';
