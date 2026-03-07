import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import {
  VaultEntry,
  VaultGroup,
  VaultData,
  VaultFileData,
  VaultFileHeader,
  SortCategory,
  EventType,
  AuditLogEntry
} from '../model/VaultModels';
import { AnyOtpInfo, OtpType, OtpAlgorithm } from '../model/OtpModels';
import { Base32, Hex, Base64, generateUUID } from '../util/Encoding';

const VAULT_FILENAME = 'aegis.json';
const VAULT_VERSION = 3;
const VAULT_FILE_VERSION = 1;

export class VaultService {
  private static instance: VaultService | undefined = undefined;

  private context: common.Context | undefined = undefined;
  private vaultData: VaultData | undefined = undefined;
  private isLocked: boolean = true;
  private lockListeners: Array<() => void> = [];

  private constructor() {
  }

  static getInstance(): VaultService {
    if (VaultService.instance === undefined) {
      VaultService.instance = new VaultService();
    }
    return VaultService.instance;
  }

  init(context: common.Context): void {
    this.context = context;
  }

  // Check if vault file exists on disk
  vaultFileExists(): boolean {
    if (this.context === undefined) {
      return false;
    }
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    try {
      return fileIo.accessSync(filePath);
    } catch (err) {
      return false;
    }
  }

  // Read the raw vault file from disk
  readVaultFileRaw(): string {
    if (this.context === undefined) {
      throw new Error('VaultService not initialized');
    }
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(filePath);
    const buffer = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buffer);
    fileIo.closeSync(file);
    const decoder = new util.TextDecoder('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer));
  }

  // Write the vault file to disk
  writeVaultFile(content: string): void {
    if (this.context === undefined) {
      throw new Error('VaultService not initialized');
    }
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const encoder = new util.TextEncoder();
    const data = encoder.encodeInto(content);
    fileIo.writeSync(file.fd, data.buffer);
    fileIo.closeSync(file);
  }

  // Initialize a new empty vault (no encryption)
  initNewVault(): void {
    this.vaultData = {
      version: VAULT_VERSION,
      entries: [],
      groups: [],
      iconsOptimized: true
    };
    this.isLocked = false;
    this.saveVault();
  }

  // Load vault from file (unencrypted only for now)
  loadVault(): void {
    const raw = this.readVaultFileRaw();
    const fileObj: VaultFileData = JSON.parse(raw) as VaultFileData;

    if (fileObj.version > VAULT_FILE_VERSION) {
      throw new Error('Unsupported vault file version');
    }

    const header = fileObj.header;
    const isEncrypted = header.slots !== undefined && header.slots !== null &&
      header.params !== undefined && header.params !== null;

    if (isEncrypted) {
      // For now, mark as locked - password unlock needed
      this.isLocked = true;
      return;
    }

    // Unencrypted vault - parse directly
    const db = fileObj.db as Record<string, Object>;
    this.parseVaultDb(db);
    this.isLocked = false;
  }

  // Parse vault database content from JSON object
  private parseVaultDb(db: Record<string, Object>): void {
    const version = db['version'] as number;
    if (version > VAULT_VERSION) {
      throw new Error('Unsupported vault version');
    }

    const entriesArr = db['entries'] as Array<Record<string, Object>>;
    const groupsArr = db['groups'] as Array<Record<string, Object>> | undefined;
    const iconsOptimized = db['icons_optimized'] as boolean | undefined;

    const groups: VaultGroup[] = [];
    if (groupsArr !== undefined) {
      for (const g of groupsArr) {
        const group: VaultGroup = {
          uuid: g['uuid'] as string,
          name: g['name'] as string
        };
        groups.push(group);
      }
    }

    const entries: VaultEntry[] = [];
    for (const e of entriesArr) {
      try {
        const entry = this.parseEntry(e);
        entries.push(entry);
      } catch (err) {
        // Skip invalid entries, don't crash
        continue;
      }
    }

    this.vaultData = {
      version: version,
      entries: entries,
      groups: groups,
      iconsOptimized: iconsOptimized !== undefined ? iconsOptimized : true
    };
  }

  // Parse a single vault entry from JSON
  private parseEntry(obj: Record<string, Object>): VaultEntry {
    const typeStr = obj['type'] as string;
    const infoObj = obj['info'] as Record<string, Object>;
    const secretStr = infoObj['secret'] as string;
    const secret = Base32.decode(secretStr);
    const algo = (infoObj['algo'] as string || 'SHA1') as OtpAlgorithm;
    const digits = infoObj['digits'] as number;

    let info: AnyOtpInfo;

    switch (typeStr) {
      case 'totp': {
        const totpInfo: AnyOtpInfo = {
          type: OtpType.TOTP,
          secret: secret,
          algorithm: algo as OtpAlgorithm,
          digits: digits,
          period: infoObj['period'] as number
        };
        info = totpInfo;
        break;
      }
      case 'steam': {
        const steamInfo: AnyOtpInfo = {
          type: OtpType.STEAM,
          secret: secret,
          algorithm: algo as OtpAlgorithm,
          digits: digits,
          period: infoObj['period'] as number
        };
        info = steamInfo;
        break;
      }
      case 'hotp': {
        const hotpInfo: AnyOtpInfo = {
          type: OtpType.HOTP,
          secret: secret,
          algorithm: algo as OtpAlgorithm,
          digits: digits,
          counter: infoObj['counter'] as number
        };
        info = hotpInfo;
        break;
      }
      case 'motp': {
        const motpInfo: AnyOtpInfo = {
          type: OtpType.MOTP,
          secret: secret,
          algorithm: OtpAlgorithm.MD5,
          digits: digits,
          period: infoObj['period'] as number || 10,
          pin: infoObj['pin'] as string || ''
        };
        info = motpInfo;
        break;
      }
      case 'yandex': {
        const yandexInfo: AnyOtpInfo = {
          type: OtpType.YANDEX,
          secret: secret,
          algorithm: OtpAlgorithm.SHA256,
          digits: 8,
          period: 30,
          pin: infoObj['pin'] as string || ''
        };
        info = yandexInfo;
        break;
      }
      default:
        throw new Error(`Unsupported OTP type: ${typeStr}`);
    }

    // Parse groups
    const groupsSet = new Set<string>();
    const groupsArr = obj['groups'] as Array<string> | undefined;
    if (groupsArr !== undefined) {
      for (const g of groupsArr) {
        groupsSet.add(g);
      }
    }

    const entry: VaultEntry = {
      uuid: obj['uuid'] as string || generateUUID(),
      name: obj['name'] as string || '',
      issuer: obj['issuer'] as string || '',
      info: info,
      icon: undefined, // Icon handling is complex, skip for now
      isFavorite: obj['favorite'] as boolean || false,
      usageCount: 0,
      lastUsedTimestamp: 0,
      note: obj['note'] as string || '',
      groups: groupsSet
    };

    return entry;
  }

  // Serialize vault to JSON and save to file
  saveVault(): void {
    if (this.vaultData === undefined) {
      throw new Error('No vault data to save');
    }

    const entriesArr: object[] = [];
    for (const entry of this.vaultData.entries) {
      entriesArr.push(this.serializeEntry(entry));
    }

    const groupsArr: object[] = [];
    for (const group of this.vaultData.groups) {
      const g: Record<string, string> = {
        'uuid': group.uuid,
        'name': group.name
      };
      groupsArr.push(g);
    }

    const db: Record<string, Object> = {
      'version': VAULT_VERSION,
      'entries': entriesArr,
      'groups': groupsArr,
      'icons_optimized': this.vaultData.iconsOptimized
    };

    const header: Record<string, Object | null> = {
      'slots': null,
      'params': null
    };

    const fileObj: Record<string, Object> = {
      'version': VAULT_FILE_VERSION,
      'header': header,
      'db': db
    };

    const json = JSON.stringify(fileObj, null, 4);
    this.writeVaultFile(json);
  }

  // Serialize a single entry to JSON-compatible object
  private serializeEntry(entry: VaultEntry): object {
    const infoObj: Record<string, Object> = {
      'secret': Base32.encode(entry.info.secret),
      'algo': entry.info.algorithm as string,
      'digits': entry.info.digits
    };

    // Add type-specific fields
    if (entry.info.type === OtpType.TOTP || entry.info.type === OtpType.STEAM) {
      infoObj['period'] = (entry.info as AnyOtpInfo & { period: number }).period;
    } else if (entry.info.type === OtpType.HOTP) {
      infoObj['counter'] = (entry.info as AnyOtpInfo & { counter: number }).counter;
    } else if (entry.info.type === OtpType.MOTP) {
      infoObj['period'] = (entry.info as AnyOtpInfo & { period: number }).period;
      infoObj['pin'] = (entry.info as AnyOtpInfo & { pin: string }).pin;
    } else if (entry.info.type === OtpType.YANDEX) {
      infoObj['pin'] = (entry.info as AnyOtpInfo & { pin: string }).pin;
    }

    const groupsArr: string[] = [];
    entry.groups.forEach((g: string) => {
      groupsArr.push(g);
    });

    const obj: Record<string, Object> = {
      'type': entry.info.type as string,
      'uuid': entry.uuid,
      'name': entry.name,
      'issuer': entry.issuer,
      'note': entry.note,
      'favorite': entry.isFavorite,
      'info': infoObj,
      'groups': groupsArr
    };

    return obj;
  }

  // --- CRUD Operations ---

  getEntries(): VaultEntry[] {
    if (this.vaultData === undefined) {
      return [];
    }
    return this.vaultData.entries;
  }

  getEntryByUUID(uuid: string): VaultEntry | undefined {
    if (this.vaultData === undefined) {
      return undefined;
    }
    return this.vaultData.entries.find((e: VaultEntry) => e.uuid === uuid);
  }

  addEntry(entry: VaultEntry): void {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }
    this.vaultData.entries.push(entry);
  }

  updateEntry(entry: VaultEntry): void {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }
    const index = this.vaultData.entries.findIndex((e: VaultEntry) => e.uuid === entry.uuid);
    if (index >= 0) {
      this.vaultData.entries[index] = entry;
    }
  }

  removeEntry(uuid: string): void {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }
    this.vaultData.entries = this.vaultData.entries.filter((e: VaultEntry) => e.uuid !== uuid);
  }

  moveEntry(fromUuid: string, toUuid: string): void {
    if (this.vaultData === undefined) {
      return;
    }
    const entries = this.vaultData.entries;
    const fromIndex = entries.findIndex((e: VaultEntry) => e.uuid === fromUuid);
    const toIndex = entries.findIndex((e: VaultEntry) => e.uuid === toUuid);
    if (fromIndex >= 0 && toIndex >= 0) {
      const entry = entries.splice(fromIndex, 1)[0];
      entries.splice(toIndex, 0, entry);
    }
  }

  // --- Group operations ---

  getGroups(): VaultGroup[] {
    if (this.vaultData === undefined) {
      return [];
    }
    return this.vaultData.groups;
  }

  addGroup(group: VaultGroup): void {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }
    this.vaultData.groups.push(group);
  }

  removeGroup(uuid: string): void {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }
    // Remove group from all entries
    for (const entry of this.vaultData.entries) {
      entry.groups.delete(uuid);
    }
    this.vaultData.groups = this.vaultData.groups.filter((g: VaultGroup) => g.uuid !== uuid);
  }

  renameGroup(uuid: string, newName: string): void {
    if (this.vaultData === undefined) {
      return;
    }
    const group = this.vaultData.groups.find((g: VaultGroup) => g.uuid === uuid);
    if (group !== undefined) {
      group.name = newName;
    }
  }

  // --- Lock/Unlock ---

  isVaultLocked(): boolean {
    return this.isLocked;
  }

  isVaultLoaded(): boolean {
    return this.vaultData !== undefined;
  }

  isVaultInitNeeded(): boolean {
    return !this.isVaultLoaded() && !this.vaultFileExists();
  }

  lock(): void {
    this.vaultData = undefined;
    this.isLocked = true;
    for (const listener of this.lockListeners) {
      listener();
    }
  }

  registerLockListener(listener: () => void): void {
    this.lockListeners.push(listener);
  }

  unregisterLockListener(listener: () => void): void {
    const index = this.lockListeners.indexOf(listener);
    if (index >= 0) {
      this.lockListeners.splice(index, 1);
    }
  }

  // Check if vault is encrypted
  isEncrypted(): boolean {
    if (!this.vaultFileExists()) {
      return false;
    }
    try {
      const raw = this.readVaultFileRaw();
      const fileObj = JSON.parse(raw) as Record<string, Object>;
      const header = fileObj['header'] as Record<string, Object>;
      return header['slots'] !== null && header['slots'] !== undefined;
    } catch (err) {
      return false;
    }
  }

  // Export vault to JSON string
  exportVault(): string {
    if (this.vaultData === undefined) {
      throw new Error('Vault not loaded');
    }

    const entriesArr: object[] = [];
    for (const entry of this.vaultData.entries) {
      entriesArr.push(this.serializeEntry(entry));
    }

    const groupsArr: object[] = [];
    for (const group of this.vaultData.groups) {
      const g: Record<string, string> = {
        'uuid': group.uuid,
        'name': group.name
      };
      groupsArr.push(g);
    }

    const db: Record<string, Object> = {
      'version': VAULT_VERSION,
      'entries': entriesArr,
      'groups': groupsArr,
      'icons_optimized': this.vaultData.iconsOptimized
    };

    const header: Record<string, Object | null> = {
      'slots': null,
      'params': null
    };

    const fileObj: Record<string, Object> = {
      'version': VAULT_FILE_VERSION,
      'header': header,
      'db': db
    };

    return JSON.stringify(fileObj, null, 4);
  }
}

import { util } from '@kit.ArkTS';
