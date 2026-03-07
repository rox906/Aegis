# Aegis Authenticator - Android Project Analysis

## 1. Manifest Analysis

**Package**: `com.beemdevelopment.aegis`

### Activities:
| Activity | Purpose | Launcher? |
|----------|---------|-----------|
| `MainActivity` | Main entry list, shows all OTP entries with codes | YES (LAUNCHER) |
| `AuthActivity` | Vault unlock screen (password/biometric) | No |
| `IntroActivity` | First-run setup wizard (welcome, security picker, setup) | No |
| `EditEntryActivity` | Add/edit OTP entry (issuer, name, secret, type, icon, groups) | No |
| `ScannerActivity` | QR code scanner for adding entries | No |
| `PreferencesActivity` | Settings screen (multiple preference fragments) | No |
| `GroupManagerActivity` | Manage groups (add/rename/delete/reorder) | No |
| `ImportEntriesActivity` | Import entries from other authenticator apps | No |
| `AssignIconsActivity` | Batch assign icons from icon packs to entries | No |
| `TransferEntriesActivity` | Transfer entries via QR codes (Google Auth migration format) | No |
| `AboutActivity` | About screen with version info, licenses | No |
| `LicensesActivity` | Open source licenses display | No |
| `PanicResponderActivity` | Guardian Project panic trigger (wipes vault) | No (exported, responds to panic intent) |
| `ExitActivity` | Helper to exit/finish the app | No |

### Intent Filters on MainActivity:
- `ACTION_MAIN` / `LAUNCHER` - app entry
- `ACTION_VIEW` with `otpauth://` scheme - handle OTP URIs
- `ACTION_SEND` / `ACTION_SEND_MULTIPLE` with `image/*` and `text/plain` - receive shared QR images/text

### Services:
- `LaunchAppTileService` - Quick Settings tile to open vault
- `LaunchScannerTileService` - Quick Settings tile to open scanner
- `NotificationService` - (DISABLED) persistent notification when vault is unlocked

### Receivers:
- `VaultLockReceiver` - Locks vault on screen off, custom lock intent
- `QsTileRefreshReceiver` - Refreshes QS tiles on boot/user unlock

### Providers:
- `FileProvider` - For sharing files (export)

### Permissions:
- `CAMERA` - QR scanning
- `USE_BIOMETRIC` - Biometric unlock
- `VIBRATE` - Haptic feedback on copy
- `RECEIVE_BOOT_COMPLETED` - QS tile refresh

## 2. Source Language
**Pure Java** - All 233 source files are `.java`

## 3. Entry Point
- **Application**: `AegisApplication` extends `AegisApplicationBase`
  - Uses Hilt (`@HiltAndroidApp`)
  - `onCreate()`: Gets VaultManager via Hilt DI, registers VaultLockReceiver for screen off, registers AppLifecycleObserver for auto-lock on minimize, clears cache dir, initializes app shortcuts
- **Launcher Activity**: `MainActivity`

## 4. Architecture
- **Pattern**: Primarily MVC with some repository pattern
- **DI**: Dagger Hilt (used for VaultManager, AuditLogRepository, Preferences injection)
- **No ViewModel layer** - Activities directly interact with VaultManager/VaultRepository
- **Vault as in-memory data store** - No Room for main data. Vault entries stored in JSON file, loaded into memory

## 5. Key Dependencies
| Dependency | Usage |
|-----------|-------|
| Dagger Hilt | DI framework |
| Room | Only for AuditLog (not for OTP entries) |
| protobuf | Google Auth migration format parsing |
| Glide | Image loading for icons |
| ZXing | QR code generation |
| CameraX | QR code scanning |
| Guava | Base32/Base16 encoding |
| libsu (topjohnwu) | Root shell access for importing from other apps |
| avito/krop | Image cropping for custom icons |
| Material Components | UI components |
| Guardian Project TrustedIntents | Panic trigger |
| AppIntro | Intro/setup wizard |

## 6. Data Storage

### Primary Storage: JSON Vault File (`aegis.json`)
The vault file is the CORE of the app. Structure:
```json
{
  "version": 1,
  "header": {
    "slots": [...],  // encryption key slots (password, biometric)
    "params": {...}   // AES-GCM encryption parameters
  },
  "db": {
    "version": 3,
    "entries": [...],  // OTP entries
    "groups": [...],   // groups for organizing entries
    "icons_optimized": true
  }
}
```
When encrypted, `db` is Base64-encoded AES-GCM ciphertext.

### VaultEntry Fields:
- uuid (UUID)
- name (String) - account name
- issuer (String) - service name
- info (OtpInfo) - OTP parameters (secret, algorithm, digits, period/counter)
- icon (VaultEntryIcon) - custom icon (JPEG/PNG/SVG bytes)
- isFavorite (boolean)
- usageCount (int) - stored in preferences, not in vault
- lastUsedTimestamp (long) - stored in preferences, not in vault
- note (String)
- groups (Set<UUID>) - group memberships

### OTP Types:
- **TOTP** (TotpInfo): secret, algorithm, digits, period
- **HOTP** (HotpInfo): secret, algorithm, digits, counter
- **Steam** (SteamInfo extends TotpInfo): Steam Guard codes with custom alphabet
- **MOTP** (MotpInfo): Mobile-OTP with PIN
- **Yandex** (YandexInfo): Yandex OTP with PIN

### Room Database (AuditLog only):
- Table: `audit_logs`
  - id (long, PK, auto)
  - event_type (EventType enum)
  - reference (String, nullable)
  - timestamp (long)
- DAO: insert(), getAll() (last 30 days, ordered by timestamp DESC)

### SharedPreferences (extensive):
Key preferences include:
- `pref_intro` (boolean) - intro completed
- `pref_tap_to_reveal` (boolean) - hide codes until tapped
- `pref_tap_to_reveal_time` (int, default 30) - reveal duration
- `pref_highlight_entry` (boolean) - highlight focused entry
- `pref_haptic_feedback` (boolean, default true)
- `pref_pause_entry` (boolean) - pause focused entry
- `pref_panic_trigger` (boolean) - panic trigger enabled
- `pref_secure_screen` (boolean, default true) - FLAG_SECURE
- `pref_password_reminder_freq` (int) - password reminder frequency
- `pref_password_reminder_counter` (long) - last password reminder timestamp
- `pref_current_sort_category` (int) - sort order
- `pref_current_theme` (int) - theme (system/light/dark)
- `pref_dynamic_colors` (boolean) - Material You
- `pref_current_view_mode` (int) - normal/compact/small/tiles
- `pref_account_name_position` (int) - end/hidden/below
- `pref_current_copy_behavior` (int) - copy on tap behavior
- `pref_auto_lock_mask` (int) - bitmask for auto-lock triggers
- `pref_search_behavior_mask` (int) - search in issuer/name/note/groups
- `pref_backups` (boolean) - built-in backups enabled
- `pref_backups_location` (String/Uri)
- `pref_backups_versions` (int, default 5)
- `pref_android_backups` (boolean)
- `pref_group_filter_uuids` (JSON array)
- `pref_usage_count` (JSON array of {uuid, count})
- `pref_last_used_timestamps` (JSON array of {uuid, timestamp})
- `pref_show_icons` (boolean, default true)
- `pref_show_next_code` (boolean)
- `pref_expiration_state` (boolean, default true)
- `pref_code_group_size_string` (String)
- `pref_pin_keyboard` (boolean) - PIN-style keyboard for password
- `pref_warn_time_sync` (boolean)
- `pref_minimize_on_copy` (boolean)
- `pref_focus_search` (boolean) - auto-focus search on launch
- `pref_lang` (String, default "system")
- `pref_shared_issuer_account_name` (boolean) - hide account name when same as issuer
- `pref_groups_multiselect` (boolean)

## 7. Encryption/Security Architecture
- **MasterKey**: AES-256 key that encrypts/decrypts the vault
- **Slots**: Multiple "slots" can decrypt the MasterKey
  - **PasswordSlot**: Derives key from password via SCrypt, then decrypts MasterKey
  - **BiometricSlot**: Uses Android KeyStore + biometric to decrypt MasterKey
  - **RawSlot**: Direct key storage (for backup)
- **Encryption**: AES-256-GCM
- **Key Derivation**: SCrypt (n, r, p, salt parameters stored per slot)

## 8. Navigation Map
```
App Launch → MainActivity (if intro done & vault exists)
           → IntroActivity (if first launch)
           → AuthActivity (if vault encrypted & locked)

MainActivity:
  → ScannerActivity (FAB → scan QR)
  → EditEntryActivity (FAB → manual entry, or tap entry to edit)
  → PreferencesActivity (menu → Settings)
  → AboutActivity (menu → About)
  → AssignIconsActivity (from preferences)
  → GroupManagerActivity (from preferences)
  → ImportEntriesActivity (from preferences)
  → TransferEntriesActivity (from preferences)

EditEntryActivity:
  → IconPickerDialog (tap icon)
  → Image picker (tap icon → choose from gallery)

ScannerActivity:
  → returns scanned URI to MainActivity

PreferencesActivity:
  → GroupManagerActivity
  → ImportEntriesActivity
  → Icon pack management
  → Backup location picker
```

## 9. Background Work
- **No WorkManager** usage
- **No AlarmManager** usage
- Auto-lock via ProcessLifecycleOwner (ON_STOP event)
- VaultLockReceiver on SCREEN_OFF
- Backup scheduling is synchronous (runs on save)

## 10. Complexity Estimate
- Activities: 14
- Fragments: ~10 (preference fragments, intro slides)
- Services: 2 (QS tiles)
- Receivers: 2
- Room Entities: 1 (AuditLogEntry)
- API Endpoints: 0 (fully offline app)
- Total source files: 233
- OTP types: 5 (TOTP, HOTP, Steam, MOTP, Yandex)
- Importers: ~20+ (from various authenticator apps)
- View modes: 4 (Normal, Compact, Small, Tiles)
- Sort categories: 7

## 11. Key User Interactions (MainActivity)

### Toolbar/Menu:
- Search (SearchView) - filter entries
- Sort (submenu with 7 sort options)
- Lock vault
- Settings
- About

### FAB Menu:
- Scan QR code (launches ScannerActivity)
- Enter manually (launches EditEntryActivity)
- Import from image (pick image, decode QR)
- Import from other apps (launches ImportEntriesActivity)

### Entry List:
- Tap entry → copy OTP code (or tap-to-reveal, depending on settings)
- Long press → action mode (select multiple)
- Action mode: copy, edit, share QR, delete, add to group, move to top/bottom
- Drag-and-drop reorder (in custom sort mode)
- Swipe-to-copy (optional)

### Group Chips:
- Filter by group chips at top
- "All" chip always present
- Multi-select groups (if enabled)

### Error Cards:
- Backup reminder
- Plaintext backup warning
- Time sync warning

## 12. Preferences Structure
PreferencesActivity contains multiple fragments:
- MainPreferencesFragment
- AppearancePreferencesFragment (theme, view mode, icons, code grouping)
- BehaviorPreferencesFragment (copy behavior, auto-lock, search, etc.)
- SecurityPreferencesFragment (encryption, biometrics, password)
- BackupsPreferencesFragment (backup configuration)
- ImportExportPreferencesFragment
- IconPacksPreferencesFragment
- AuditLogPreferencesFragment
