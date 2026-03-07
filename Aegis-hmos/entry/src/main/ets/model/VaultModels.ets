import { AnyOtpInfo } from './OtpModels';

// Vault Entry - represents a single OTP account
export interface VaultEntry {
  uuid: string;
  name: string;
  issuer: string;
  info: AnyOtpInfo;
  icon: VaultEntryIcon | undefined;
  isFavorite: boolean;
  usageCount: number;
  lastUsedTimestamp: number;
  note: string;
  groups: Set<string>; // Set of group UUIDs
}

// Entry icon - stored as byte array with type info
export interface VaultEntryIcon {
  type: IconType;
  data: Uint8Array;
}

export enum IconType {
  JPEG = 'jpeg',
  PNG = 'png',
  SVG = 'svg'
}

// Vault Group
export interface VaultGroup {
  uuid: string;
  name: string;
}

// Vault - the complete in-memory vault containing entries and groups
export interface VaultData {
  version: number;
  entries: VaultEntry[];
  groups: VaultGroup[];
  iconsOptimized: boolean;
}

// Vault File structure (JSON file format)
export interface VaultFileHeader {
  slots: SlotData[] | undefined;
  params: CryptParams | undefined;
}

export interface VaultFileData {
  version: number;
  header: VaultFileHeader;
  db: string | object; // Base64 encrypted string or plain JSON object
}

// Encryption parameters
export interface CryptParams {
  nonce: Uint8Array;
  tag: Uint8Array;
}

// Slot types
export enum SlotType {
  RAW = 0,
  PASSWORD = 1,
  BIOMETRIC = 2
}

// Base slot data
export interface SlotData {
  type: SlotType;
  uuid: string;
  key: Uint8Array; // encrypted master key
  keyParams: CryptParams;
}

// Password slot additional data
export interface PasswordSlotData extends SlotData {
  type: SlotType.PASSWORD;
  n: number; // SCrypt N
  r: number; // SCrypt r
  p: number; // SCrypt p
  salt: Uint8Array;
  repaired: boolean;
  isBackup: boolean;
}

// SCrypt parameters
export interface SCryptParams {
  n: number;
  r: number;
  p: number;
  salt: Uint8Array;
}

// Sort categories
export enum SortCategory {
  CUSTOM = 0,
  ACCOUNT = 1,
  ACCOUNT_REVERSED = 2,
  ISSUER = 3,
  ISSUER_REVERSED = 4,
  USAGE_COUNT = 5,
  LAST_USED = 6
}

// View modes for entry list
export enum ViewMode {
  NORMAL = 0,
  COMPACT = 1,
  SMALL = 2,
  TILES = 3
}

// Copy behavior
export enum CopyBehavior {
  NEVER = 0,
  SINGLETAP = 1,
  DOUBLETAP = 2
}

// Account name position
export enum AccountNamePosition {
  END = 0,
  HIDDEN = 1,
  BELOW = 2
}

// Code grouping
export enum CodeGrouping {
  HALVES = -1,
  NO_GROUPING = -2,
  GROUPING_TWOS = 2,
  GROUPING_THREES = 3,
  GROUPING_FOURS = 4
}

// Theme
export enum AppTheme {
  SYSTEM = 0,
  LIGHT = 1,
  DARK = 2,
  AMOLED = 3,
  SYSTEM_AMOLED = 4
}

// Password reminder frequency
export enum PassReminderFreq {
  NEVER = 0,
  WEEKLY = 1,
  BIWEEKLY = 2,
  MONTHLY = 3,
  QUARTERLY = 4
}

// Auto-lock flags
export const AUTO_LOCK_OFF: number = 1;
export const AUTO_LOCK_ON_BACK_BUTTON: number = 2;
export const AUTO_LOCK_ON_MINIMIZE: number = 4;
export const AUTO_LOCK_ON_DEVICE_LOCK: number = 8;

// Search behavior flags
export const SEARCH_IN_ISSUER: number = 1;
export const SEARCH_IN_NAME: number = 2;
export const SEARCH_IN_NOTE: number = 4;
export const SEARCH_IN_GROUPS: number = 8;

// Audit log event types
export enum EventType {
  VAULT_UNLOCKED = 0,
  VAULT_BACKUP_CREATED = 1,
  VAULT_ANDROID_BACKUP_CREATED = 2,
  VAULT_EXPORTED = 3,
  ENTRY_SHARED = 4,
  VAULT_UNLOCK_FAILED_PASSWORD = 5,
  VAULT_UNLOCK_FAILED_BIOMETRICS = 6
}

// Audit log entry
export interface AuditLogEntry {
  id: number;
  eventType: EventType;
  reference: string;
  timestamp: number;
}

// Group placeholder type
export enum GroupPlaceholderType {
  NONE = 0,
  NO_GROUP = 1,
  FAVORITES = 2
}
