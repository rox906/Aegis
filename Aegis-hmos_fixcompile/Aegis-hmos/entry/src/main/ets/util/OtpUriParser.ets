import { VaultEntry } from '../model/VaultModels';
import {
  AnyOtpInfo,
  OtpType,
  OtpAlgorithm,
  TotpInfo,
  HotpInfo,
  SteamInfo,
  MotpInfo,
  YandexInfo,
  OTP_DEFAULT_DIGITS,
  OTP_DEFAULT_ALGORITHM,
  TOTP_DEFAULT_PERIOD,
  HOTP_DEFAULT_COUNTER,
  STEAM_DEFAULT_DIGITS
} from '../model/OtpModels';
import { Base32, Hex } from './Encoding';
import { generateUUID } from './Encoding';

export interface ParsedOtpUri {
  name: string;
  issuer: string;
  info: AnyOtpInfo;
}

/**
 * Parses an otpauth:// URI into its component parts.
 *
 * URI format: otpauth://TYPE/LABEL?PARAMS
 * - TYPE: totp, hotp, steam, yandex, motp
 * - LABEL: issuer:accountName or just accountName
 * - PARAMS: secret, issuer, algorithm, digits, period, counter, pin
 */
export function parseOtpUri(uriString: string): ParsedOtpUri {
  const trimmed: string = uriString.trim();

  // 1. Extract scheme and remainder by splitting on "://"
  const schemeSepIndex: number = trimmed.indexOf('://');
  if (schemeSepIndex === -1) {
    throw new Error('Invalid OTP URI: missing "://" separator');
  }

  const scheme: string = trimmed.substring(0, schemeSepIndex).toLowerCase();
  const remainder: string = trimmed.substring(schemeSepIndex + 3);

  // Scheme must be "otpauth" or "motp"
  if (scheme !== 'otpauth' && scheme !== 'motp') {
    throw new Error(`Invalid OTP URI scheme: "${scheme}". Expected "otpauth" or "motp".`);
  }

  // 2. Split remainder into path and query
  let pathPart: string;
  let queryPart: string = '';
  const queryIndex: number = remainder.indexOf('?');
  if (queryIndex !== -1) {
    pathPart = remainder.substring(0, queryIndex);
    queryPart = remainder.substring(queryIndex + 1);
  } else {
    pathPart = remainder;
  }

  // 3. Extract type and label from path
  // Path format: TYPE/LABEL or TYPE/LABEL (with possible leading slash variants)
  const firstSlash: number = pathPart.indexOf('/');
  let typeStr: string;
  let label: string;

  if (firstSlash === -1) {
    // No label present, just the type
    typeStr = pathPart;
    label = '';
  } else {
    typeStr = pathPart.substring(0, firstSlash);
    label = pathPart.substring(firstSlash + 1);
  }

  // Handle motp:// scheme - type is motp, the "host" part may be empty or absent
  if (scheme === 'motp') {
    // For motp:// URIs, the type is implicitly motp
    // The remainder is the label + params
    if (typeStr.length > 0 && typeStr !== 'motp') {
      // The "type" portion is actually part of the label
      label = typeStr + (label.length > 0 ? '/' + label : '');
    }
    typeStr = 'motp';
  }

  typeStr = typeStr.toLowerCase();

  // 4. URL-decode the label
  label = decodeURIComponent(label);
  // Remove leading/trailing slashes and whitespace from label
  label = label.replace(/^\/+/, '').replace(/\/+$/, '').trim();

  // 5. Parse issuer and name from label
  let labelIssuer: string = '';
  let name: string = '';
  const colonIndex: number = label.indexOf(':');
  if (colonIndex !== -1) {
    labelIssuer = label.substring(0, colonIndex).trim();
    name = label.substring(colonIndex + 1).trim();
  } else {
    name = label;
  }

  // 6. Parse query string into key-value pairs
  const params: Map<string, string> = parseQueryString(queryPart);

  // 7. Extract and validate secret (required)
  const secretParam: string | undefined = params.get('secret');
  if (secretParam === undefined || secretParam.length === 0) {
    throw new Error('Invalid OTP URI: missing required "secret" parameter');
  }

  // Decode secret: hex for motp, base32 for everything else
  let secret: Uint8Array;
  if (typeStr === 'motp') {
    secret = Hex.decode(secretParam);
  } else {
    secret = Base32.decode(secretParam);
  }

  if (secret.length === 0) {
    throw new Error('Invalid OTP URI: secret decoded to empty bytes');
  }

  // 8. Issuer from query overrides issuer from label
  const queryIssuer: string | undefined = params.get('issuer');
  let issuer: string;
  if (queryIssuer !== undefined && queryIssuer.length > 0) {
    issuer = decodeURIComponent(queryIssuer);
  } else {
    issuer = labelIssuer;
  }

  // 9. Parse algorithm
  const algorithm: OtpAlgorithm = parseAlgorithm(params.get('algorithm'));

  // 10. Parse digits
  const digitsParam: string | undefined = params.get('digits');
  let digits: number;
  if (digitsParam !== undefined && digitsParam.length > 0) {
    digits = parseInt(digitsParam, 10);
    if (isNaN(digits) || digits < 1) {
      throw new Error(`Invalid OTP URI: invalid digits value "${digitsParam}"`);
    }
  } else if (typeStr === 'steam') {
    digits = STEAM_DEFAULT_DIGITS;
  } else {
    digits = OTP_DEFAULT_DIGITS;
  }

  // 11. Parse period
  const periodParam: string | undefined = params.get('period');
  let period: number = TOTP_DEFAULT_PERIOD;
  if (periodParam !== undefined && periodParam.length > 0) {
    period = parseInt(periodParam, 10);
    if (isNaN(period) || period < 1) {
      throw new Error(`Invalid OTP URI: invalid period value "${periodParam}"`);
    }
  }

  // 12. Parse counter (for HOTP)
  const counterParam: string | undefined = params.get('counter');
  let counter: number = HOTP_DEFAULT_COUNTER;
  if (counterParam !== undefined && counterParam.length > 0) {
    counter = parseInt(counterParam, 10);
    if (isNaN(counter) || counter < 0) {
      throw new Error(`Invalid OTP URI: invalid counter value "${counterParam}"`);
    }
  }

  // 13. Parse pin (for mOTP and Yandex)
  const pin: string = params.get('pin') ?? '';

  // 14. Build the appropriate OtpInfo based on type
  const info: AnyOtpInfo = buildOtpInfo(typeStr, secret, algorithm, digits, period, counter, pin);

  return {
    name: name,
    issuer: issuer,
    info: info
  };
}

/**
 * Creates a full VaultEntry from an otpauth:// URI string.
 */
export function createVaultEntryFromUri(uriString: string): VaultEntry {
  const parsed: ParsedOtpUri = parseOtpUri(uriString);
  const entry: VaultEntry = {
    uuid: generateUUID(),
    name: parsed.name,
    issuer: parsed.issuer,
    info: parsed.info,
    icon: undefined,
    isFavorite: false,
    usageCount: 0,
    lastUsedTimestamp: 0,
    note: '',
    groups: new Set<string>()
  };
  return entry;
}

/**
 * Parses a query string (without leading "?") into a Map of key-value pairs.
 * Values are URL-decoded.
 */
function parseQueryString(query: string): Map<string, string> {
  const result: Map<string, string> = new Map<string, string>();
  if (query.length === 0) {
    return result;
  }

  const pairs: string[] = query.split('&');
  for (let i = 0; i < pairs.length; i++) {
    const pair: string = pairs[i];
    const eqIndex: number = pair.indexOf('=');
    if (eqIndex === -1) {
      result.set(decodeURIComponent(pair).toLowerCase(), '');
    } else {
      const key: string = decodeURIComponent(pair.substring(0, eqIndex)).toLowerCase();
      const value: string = decodeURIComponent(pair.substring(eqIndex + 1));
      result.set(key, value);
    }
  }
  return result;
}

/**
 * Parses an algorithm string into an OtpAlgorithm enum value.
 * Defaults to SHA1 if not provided or unrecognized.
 */
function parseAlgorithm(algStr: string | undefined): OtpAlgorithm {
  if (algStr === undefined || algStr.length === 0) {
    return OTP_DEFAULT_ALGORITHM;
  }
  const upper: string = algStr.toUpperCase();
  if (upper === 'SHA1' || upper === 'SHA-1') {
    return OtpAlgorithm.SHA1;
  } else if (upper === 'SHA256' || upper === 'SHA-256') {
    return OtpAlgorithm.SHA256;
  } else if (upper === 'SHA512' || upper === 'SHA-512') {
    return OtpAlgorithm.SHA512;
  } else if (upper === 'MD5') {
    return OtpAlgorithm.MD5;
  } else {
    throw new Error(`Unsupported OTP algorithm: "${algStr}"`);
  }
}

/**
 * Builds the appropriate AnyOtpInfo variant based on the OTP type string.
 */
function buildOtpInfo(
  typeStr: string,
  secret: Uint8Array,
  algorithm: OtpAlgorithm,
  digits: number,
  period: number,
  counter: number,
  pin: string
): AnyOtpInfo {
  switch (typeStr) {
    case 'totp': {
      const info: TotpInfo = {
        type: OtpType.TOTP,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: period
      };
      return info;
    }
    case 'hotp': {
      const info: HotpInfo = {
        type: OtpType.HOTP,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        counter: counter
      };
      return info;
    }
    case 'steam': {
      const info: SteamInfo = {
        type: OtpType.STEAM,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: period
      };
      return info;
    }
    case 'motp': {
      if (pin.length === 0) {
        throw new Error('Invalid OTP URI: mOTP type requires a "pin" parameter');
      }
      const info: MotpInfo = {
        type: OtpType.MOTP,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: period,
        pin: pin
      };
      return info;
    }
    case 'yandex': {
      const info: YandexInfo = {
        type: OtpType.YANDEX,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: period,
        pin: pin
      };
      return info;
    }
    default:
      throw new Error(`Unsupported OTP type: "${typeStr}"`);
  }
}
