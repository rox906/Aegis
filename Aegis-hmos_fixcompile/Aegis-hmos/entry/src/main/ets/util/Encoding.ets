// Base32 encoding/decoding (RFC 4648)
const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export class Base32 {
  static decode(input: string): Uint8Array {
    const s = input.toUpperCase().replace(/=+$/, '').replace(/-/g, '').replace(/ /g, '');
    if (s.length === 0) {
      return new Uint8Array(0);
    }

    const output = new Uint8Array(Math.floor(s.length * 5 / 8));
    let bits = 0;
    let value = 0;
    let index = 0;

    for (let i = 0; i < s.length; i++) {
      const charIndex = BASE32_ALPHABET.indexOf(s.charAt(i));
      if (charIndex === -1) {
        throw new Error(`Invalid Base32 character: ${s.charAt(i)}`);
      }
      value = (value << 5) | charIndex;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        output[index] = (value >>> bits) & 0xff;
        index++;
      }
    }
    return output.slice(0, index);
  }

  static encode(data: Uint8Array): string {
    if (data.length === 0) {
      return '';
    }

    let bits = 0;
    let value = 0;
    let result = '';

    for (let i = 0; i < data.length; i++) {
      value = (value << 8) | data[i];
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        result += BASE32_ALPHABET.charAt((value >>> bits) & 0x1f);
      }
    }

    if (bits > 0) {
      result += BASE32_ALPHABET.charAt((value << (5 - bits)) & 0x1f);
    }

    return result;
  }
}

// Hex encoding/decoding
export class Hex {
  static decode(input: string): Uint8Array {
    const s = input.replace(/\s/g, '');
    if (s.length % 2 !== 0) {
      throw new Error('Invalid hex string length');
    }

    const result = new Uint8Array(s.length / 2);
    for (let i = 0; i < s.length; i += 2) {
      const byte = parseInt(s.substring(i, i + 2), 16);
      if (isNaN(byte)) {
        throw new Error(`Invalid hex character at position ${i}`);
      }
      result[i / 2] = byte;
    }
    return result;
  }

  static encode(data: Uint8Array): string {
    let result = '';
    for (let i = 0; i < data.length; i++) {
      result += data[i].toString(16).padStart(2, '0');
    }
    return result;
  }
}

// Base64 encoding/decoding
const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

export class Base64 {
  static decode(input: string): Uint8Array {
    const s = input.replace(/\s/g, '').replace(/=+$/, '');
    const byteLength = Math.floor(s.length * 3 / 4);
    const result = new Uint8Array(byteLength);
    let p = 0;

    for (let i = 0; i < s.length; i += 4) {
      const a = BASE64_CHARS.indexOf(s.charAt(i));
      const b = i + 1 < s.length ? BASE64_CHARS.indexOf(s.charAt(i + 1)) : 0;
      const c = i + 2 < s.length ? BASE64_CHARS.indexOf(s.charAt(i + 2)) : 0;
      const d = i + 3 < s.length ? BASE64_CHARS.indexOf(s.charAt(i + 3)) : 0;

      result[p] = ((a & 0x3f) << 2) | ((b >> 4) & 0x03);
      p++;
      if (p < byteLength) {
        result[p] = ((b & 0x0f) << 4) | ((c >> 2) & 0x0f);
        p++;
      }
      if (p < byteLength) {
        result[p] = ((c & 0x03) << 6) | (d & 0x3f);
        p++;
      }
    }

    return result;
  }

  static encode(data: Uint8Array): string {
    let result = '';
    for (let i = 0; i < data.length; i += 3) {
      const a = data[i];
      const b = i + 1 < data.length ? data[i + 1] : 0;
      const c = i + 2 < data.length ? data[i + 2] : 0;

      result += BASE64_CHARS.charAt(a >> 2);
      result += BASE64_CHARS.charAt(((a & 0x03) << 4) | (b >> 4));
      result += i + 1 < data.length ? BASE64_CHARS.charAt(((b & 0x0f) << 2) | (c >> 6)) : '=';
      result += i + 2 < data.length ? BASE64_CHARS.charAt(c & 0x3f) : '=';
    }
    return result;
  }
}

// UUID generation
export function generateUUID(): string {
  const bytes = new Uint8Array(16);
  for (let i = 0; i < 16; i++) {
    bytes[i] = Math.floor(Math.random() * 256);
  }
  // Set version 4
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex = Hex.encode(bytes);
  return `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}`;
}
