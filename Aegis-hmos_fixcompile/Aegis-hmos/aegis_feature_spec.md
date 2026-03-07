# Aegis Authenticator - Atomic Feature Decomposition Specification

## Document Info
- **Source Project**: Aegis Authenticator (Android, Pure Java)
- **Target Platform**: HarmonyOS NEXT (ArkTS)
- **Total Source Files Analyzed**: 233 Java files, 60+ layout XMLs, 7 menu XMLs
- **Analysis Date**: 2026-03-05

---

## A. Screen Inventory & Per-Screen Feature Points

### A1. MainActivity (Entry List Screen) - Launcher

#### A1.1 Navigation FPs

- [ ] **FP-A1-NAV-01** Launch app from home screen
  - Trigger: User taps app icon
  - Input: None
  - Process: App starts, checks if intro is done (`pref_intro`), if vault file exists, if vault is locked
  - Output: Shows MainActivity if unlocked, IntroActivity if first launch, AuthActivity if locked
  - Error: If vault file is corrupt, shows error dialog

- [ ] **FP-A1-NAV-02** Navigate to IntroActivity on first launch
  - Trigger: App detects `pref_intro == false` or vault file missing
  - Input: None
  - Process: Launches IntroActivity via `introResultLauncher`
  - Output: IntroActivity displayed
  - Error: N/A

- [ ] **FP-A1-NAV-03** Navigate to AuthActivity when vault is locked
  - Trigger: Vault file exists but not loaded (encrypted)
  - Input: None
  - Process: Launches AuthActivity via `authResultLauncher`
  - Output: AuthActivity displayed
  - Error: If vault file read fails, shows error dialog

- [ ] **FP-A1-NAV-04** Navigate to Settings (PreferencesActivity)
  - Trigger: User taps "Settings" in overflow menu
  - Input: None
  - Process: Launches PreferencesActivity via `preferenceResultLauncher`
  - Output: PreferencesActivity displayed
  - Error: N/A

- [ ] **FP-A1-NAV-05** Navigate to About screen
  - Trigger: User taps "About" in overflow menu
  - Input: None
  - Process: Launches AboutActivity
  - Output: AboutActivity displayed
  - Error: N/A

- [ ] **FP-A1-NAV-06** Navigate to ScannerActivity via FAB
  - Trigger: User opens FAB menu and taps "Scan QR code"
  - Input: Camera permission check
  - Process: If permission granted, launches ScannerActivity via `scanResultLauncher`
  - Output: ScannerActivity with camera preview
  - Error: If no camera permission, requests it; if denied, shows toast

- [ ] **FP-A1-NAV-07** Navigate to EditEntryActivity for manual entry
  - Trigger: User opens FAB menu and taps "Enter manually"
  - Input: Default empty VaultEntry
  - Process: Launches EditEntryActivity with `isManual=true` via `addEntryResultLauncher`
  - Output: EditEntryActivity with empty form
  - Error: N/A

- [ ] **FP-A1-NAV-08** Navigate to EditEntryActivity for editing existing entry
  - Trigger: User selects single entry in action mode and taps edit icon
  - Input: Entry UUID
  - Process: Launches EditEntryActivity with `entryUUID` via `editEntryResultLauncher`
  - Output: EditEntryActivity with pre-filled form
  - Error: N/A

- [ ] **FP-A1-NAV-09** Handle otpauth:// URI intent
  - Trigger: External app sends `otpauth://` URI via VIEW intent
  - Input: URI string
  - Process: Parses GoogleAuthInfo from URI, creates VaultEntry, opens add dialog
  - Output: Prompts user to add entry
  - Error: If URI parse fails, shows error dialog

- [ ] **FP-A1-NAV-10** Handle shared image/text intent
  - Trigger: External app shares image or text via SEND/SEND_MULTIPLE intent
  - Input: Image URI or text
  - Process: Decodes QR from image or parses URI from text
  - Output: Entry add flow
  - Error: If no QR found in image, shows error

- [ ] **FP-A1-NAV-11** Scan QR from image via FAB
  - Trigger: User opens FAB menu and taps "Scan image"
  - Input: Image picker intent
  - Process: Opens file picker, decodes QR from selected image via QrDecodeTask
  - Output: Entry add flow
  - Error: If no QR found, shows error dialog

#### A1.2 Data Display FPs

- [ ] **FP-A1-DSP-01** Display entry list with OTP codes
  - Trigger: Vault is loaded/unlocked
  - Input: Collection of VaultEntry objects from VaultRepository
  - Process: EntryAdapter receives entries, applies sort/filter, binds to EntryHolder
  - Output: RecyclerView showing entries with issuer, account name, and OTP code
  - Error: If OTP generation fails for an entry, shows "ERROR" text

- [ ] **FP-A1-DSP-02** Display TOTP countdown progress bar
  - Trigger: Entry list displayed with TOTP entries
  - Input: TOTP period (default 30s)
  - Process: TotpProgressBar animates based on `getMillisTillNextRotation()`; if period is uniform across entries, global bar; if non-uniform, per-entry bar
  - Output: Circular/linear progress bar counting down to next code refresh
  - Error: N/A

- [ ] **FP-A1-DSP-03** Auto-refresh TOTP codes on period expiry
  - Trigger: TOTP period expires (timer reaches 0)
  - Input: Current system time
  - Process: UiRefresher calls `refreshCode()` on EntryHolder, re-generates OTP via `TotpInfo.getOtp(time)`
  - Output: New OTP code displayed
  - Error: N/A

- [ ] **FP-A1-DSP-04** Display entry icon (custom or text drawable)
  - Trigger: Entry is bound to holder
  - Input: VaultEntryIcon (JPEG/PNG/SVG bytes) or issuer+name for TextDrawable
  - Process: GlideHelper loads icon from bytes; if no custom icon, generates TextDrawable from first letter
  - Output: Icon displayed in ImageView
  - Error: If icon loading fails, falls back to TextDrawable

- [ ] **FP-A1-DSP-05** Display favorite indicator
  - Trigger: Entry has `isFavorite == true`
  - Input: Entry.isFavorite
  - Process: Sets favorite indicator visibility to VISIBLE
  - Output: Star/dot indicator shown on entry card
  - Error: N/A

- [ ] **FP-A1-DSP-06** Display group filter chips
  - Trigger: Vault has groups defined
  - Input: Collection of VaultGroup from vault
  - Process: Creates Chip for each group + "No group" placeholder; adds to ChipGroup
  - Output: Horizontal scrollable chip bar below toolbar
  - Error: N/A (chips hidden if no groups)

- [ ] **FP-A1-DSP-07** Display footer with entry count
  - Trigger: Entry list is displayed
  - Input: Number of shown entries
  - Process: FooterView shows "X entries shown" with bold count
  - Output: Footer at bottom of list
  - Error: N/A

- [ ] **FP-A1-DSP-08** Display error card (backup reminder)
  - Trigger: `isBackupsReminderNeeded() == true` and no backup configured
  - Input: Backup state from preferences
  - Process: ErrorCardInfo created and shown at top of list
  - Output: Warning card with action button
  - Error: N/A

- [ ] **FP-A1-DSP-09** Display error card (plaintext warning)
  - Trigger: Vault has no encryption enabled and `isPlaintextBackupWarningNeeded() == true`
  - Input: Encryption state
  - Process: ErrorCardInfo shown with warning about unencrypted vault
  - Output: Warning card at top
  - Error: N/A

- [ ] **FP-A1-DSP-10** Display error card (time sync warning)
  - Trigger: System time is significantly off and `isTimeSyncWarningEnabled() == true`
  - Input: System time comparison
  - Process: ErrorCardInfo shown with time sync warning
  - Output: Warning card
  - Error: N/A

- [ ] **FP-A1-DSP-11** Display next code for TOTP entries
  - Trigger: `pref_show_next_code == true`
  - Input: Current time + one period offset
  - Process: Calls `TotpInfo.getOtp(time + period)` for next period
  - Output: Smaller "next code" text shown below current code
  - Error: N/A

- [ ] **FP-A1-DSP-12** Code grouping display
  - Trigger: `pref_code_group_size_string` preference set
  - Input: OTP string and grouping setting (HALVES, NO_GROUPING, TWOS, THREES, FOURS)
  - Process: `formatCode()` in EntryHolder inserts spaces at group boundaries
  - Output: Code displayed as "123 456" or "12 34 56" etc.
  - Error: N/A

- [ ] **FP-A1-DSP-13** Expiration state animation
  - Trigger: `pref_expiration_state == true` and TOTP nearing expiry
  - Input: Millis till next rotation
  - Process: When <7s remaining, code text color shifts to error color; when <3s, blinks
  - Output: Visual urgency cue on expiring codes
  - Error: N/A

#### A1.3 Interaction FPs

- [ ] **FP-A1-INT-01** Copy OTP code on single tap
  - Trigger: User taps entry when `pref_current_copy_behavior == SINGLETAP`
  - Input: Entry
  - Process: Generates OTP, copies to clipboard with sensitive flag; optionally sets clipboard expiry
  - Output: "Copied" animation on entry; code in clipboard
  - Error: N/A

- [ ] **FP-A1-INT-02** Copy OTP code on double tap
  - Trigger: User double-taps entry when `pref_current_copy_behavior == DOUBLETAP`
  - Input: Entry
  - Process: First tap recorded, second tap within `DoubleTapTimeout` triggers copy
  - Output: "Copied" animation on entry; code in clipboard
  - Error: N/A

- [ ] **FP-A1-INT-03** Tap to reveal hidden code
  - Trigger: User taps entry when `pref_tap_to_reveal == true`
  - Input: Entry
  - Process: Shows actual OTP code, hides other entries' codes; starts timer for `pref_tap_to_reveal_time` seconds
  - Output: Tapped entry shows code, others show dots (HIDDEN_CHAR = bullet)
  - Error: N/A

- [ ] **FP-A1-INT-04** Highlight focused entry
  - Trigger: User taps entry when `pref_highlight_entry == true`
  - Input: Entry
  - Process: Focused entry gets full alpha, others dim to 0.2 alpha
  - Output: Visual focus effect
  - Error: N/A

- [ ] **FP-A1-INT-05** Pause focused entry timer
  - Trigger: `pref_pause_entry == true` and entry is focused
  - Input: Entry
  - Process: Stops refreshing the OTP code for focused entry; code stays static
  - Output: Code frozen until focus removed
  - Error: N/A

- [ ] **FP-A1-INT-06** Long press to enter selection mode
  - Trigger: User long-presses an entry
  - Input: Entry
  - Process: Starts ActionMode, adds entry to selection, shows action bar with selection actions
  - Output: Entry highlighted with check mark, action mode toolbar shown
  - Error: N/A

- [ ] **FP-A1-INT-07** Multi-select entries in action mode
  - Trigger: User taps additional entries while in action mode
  - Input: Entry
  - Process: Toggles entry selection state; updates action mode title with count
  - Output: Multiple entries selected with check marks
  - Error: N/A

- [ ] **FP-A1-INT-08** Select all entries
  - Trigger: User taps "Select all" in action mode overflow menu
  - Input: All shown entries
  - Process: Adds all visible entries to selection
  - Output: All entries highlighted
  - Error: N/A

- [ ] **FP-A1-INT-09** Copy code from action mode
  - Trigger: User taps copy icon in action mode (single selection)
  - Input: Selected entry
  - Process: Generates and copies OTP code
  - Output: Code copied to clipboard, action mode closed
  - Error: N/A

- [ ] **FP-A1-INT-10** Delete entries from action mode
  - Trigger: User taps delete icon in action mode
  - Input: Selected entries list
  - Process: Shows confirmation dialog listing entries; on confirm, removes from vault, saves
  - Output: Entries removed from list
  - Error: If save fails, shows error toast

- [ ] **FP-A1-INT-11** Toggle favorite from action mode
  - Trigger: User taps star icon in action mode
  - Input: Selected entries
  - Process: Toggles `isFavorite` on each; favorites sort to top via FavoriteComparator
  - Output: Entries move to top/bottom; star indicator updates
  - Error: N/A

- [ ] **FP-A1-INT-12** Share entry as QR code from action mode
  - Trigger: User taps QR icon in action mode
  - Input: Selected entries
  - Process: Converts each to GoogleAuthInfo, launches TransferEntriesActivity with list
  - Output: QR code display screen
  - Error: If URI generation fails, shows error

- [ ] **FP-A1-INT-13** Assign icons from action mode
  - Trigger: User taps "Assign icons" in action mode overflow
  - Input: Selected entries
  - Process: Launches AssignIconsActivity with selected entry UUIDs
  - Output: Icon assignment screen
  - Error: N/A

- [ ] **FP-A1-INT-14** Assign groups from action mode
  - Trigger: User taps "Assign groups" in action mode overflow
  - Input: Selected entries
  - Process: Shows group selection bottom sheet
  - Output: Groups assigned to entries
  - Error: N/A

- [ ] **FP-A1-INT-15** Drag-and-drop reorder entries
  - Trigger: User long-presses single selected entry and drags in Custom sort mode
  - Input: Source and target positions
  - Process: `onItemMove()` calls `vault.moveEntry()`; only allowed when sort=CUSTOM, no filter, no search
  - Output: Entry moves to new position; vault order updated
  - Error: Drag disabled if filter/search active or sort != CUSTOM

- [ ] **FP-A1-INT-16** HOTP refresh button
  - Trigger: User taps refresh icon on HOTP entry
  - Input: HOTP entry
  - Process: Increments counter via `HotpInfo.incrementCounter()`; regenerates OTP; saves vault
  - Output: New code displayed; counter persisted
  - Error: If counter increment fails, runtime exception

- [ ] **FP-A1-INT-17** Minimize on copy
  - Trigger: Code is copied and `pref_minimize_on_copy == true`
  - Input: Copy event
  - Process: Calls `moveTaskToBack(true)` after copy
  - Output: App goes to background
  - Error: N/A

- [ ] **FP-A1-INT-18** Haptic feedback on copy
  - Trigger: Code is copied and `pref_haptic_feedback == true`
  - Input: Copy event
  - Process: Vibrates device briefly
  - Output: Tactile feedback
  - Error: N/A

- [ ] **FP-A1-INT-19** Increment usage count on tap
  - Trigger: User taps an entry
  - Input: Entry UUID
  - Process: Increments `_usageCounts[uuid]`; updates `_lastUsedTimestamps[uuid]` to now
  - Output: Stored in preferences for sort-by-usage
  - Error: N/A

#### A1.4 Menu FPs

- [ ] **FP-A1-MNU-01** Search entries
  - Trigger: User taps search icon in toolbar
  - Input: Search query text
  - Process: SearchView expands; `setSearchFilter()` on adapter filters entries by issuer/name/note/groups based on `pref_search_behavior_mask`
  - Output: Entry list filtered to matching entries
  - Error: N/A

- [ ] **FP-A1-MNU-02** Search auto-focus on launch
  - Trigger: `pref_focus_search == true` and vault loads
  - Input: None
  - Process: Automatically expands and focuses SearchView
  - Output: Keyboard shown with search focused
  - Error: N/A

- [ ] **FP-A1-MNU-03** Sort by custom order
  - Trigger: User selects "Custom" in sort submenu
  - Input: SortCategory.CUSTOM
  - Process: No comparator applied; entries in vault file order
  - Output: Entries in drag-drop order
  - Error: N/A

- [ ] **FP-A1-MNU-04** Sort by account name (A-Z)
  - Trigger: User selects sort option
  - Input: SortCategory.ACCOUNT
  - Process: Sorts by AccountNameComparator then IssuerNameComparator
  - Output: Entries sorted alphabetically by account name
  - Error: N/A

- [ ] **FP-A1-MNU-05** Sort by account name (Z-A)
  - Trigger: User selects sort option
  - Input: SortCategory.ACCOUNT_REVERSED
  - Process: Reverse of ACCOUNT sort
  - Output: Entries sorted reverse alphabetically by account name
  - Error: N/A

- [ ] **FP-A1-MNU-06** Sort by issuer (A-Z)
  - Trigger: User selects sort option
  - Input: SortCategory.ISSUER
  - Process: Sorts by IssuerNameComparator then AccountNameComparator
  - Output: Entries sorted alphabetically by issuer
  - Error: N/A

- [ ] **FP-A1-MNU-07** Sort by issuer (Z-A)
  - Trigger: User selects sort option
  - Input: SortCategory.ISSUER_REVERSED
  - Process: Reverse of ISSUER sort
  - Output: Entries sorted reverse alphabetically by issuer
  - Error: N/A

- [ ] **FP-A1-MNU-08** Sort by usage count
  - Trigger: User selects sort option
  - Input: SortCategory.USAGE_COUNT
  - Process: Sorts by UsageCountComparator (descending)
  - Output: Most-used entries first
  - Error: N/A

- [ ] **FP-A1-MNU-09** Sort by last used
  - Trigger: User selects sort option
  - Input: SortCategory.LAST_USED
  - Process: Sorts by LastUsedComparator (descending)
  - Output: Most recently used entries first
  - Error: N/A

- [ ] **FP-A1-MNU-10** Lock vault from menu
  - Trigger: User taps lock icon in toolbar
  - Input: None
  - Process: Calls `_vaultManager.lock(true)`; clears entries; notifies all LockListeners
  - Output: Vault locked; all activities finish; back to auth screen on next open
  - Error: N/A

- [ ] **FP-A1-MNU-11** FAB menu open/close
  - Trigger: User taps FAB button
  - Input: None
  - Process: FabMenuHelper toggles menu visibility with scrim overlay animation
  - Output: Menu items (Scan QR, Scan Image, Enter Manually) shown/hidden
  - Error: N/A

#### A1.5 Filter FPs

- [ ] **FP-A1-FLT-01** Filter by single group
  - Trigger: User taps a group chip (single-select mode)
  - Input: Group UUID
  - Process: Sets `_groupFilter` to selected group; adapter re-filters
  - Output: Only entries in selected group shown
  - Error: N/A

- [ ] **FP-A1-FLT-02** Filter by multiple groups
  - Trigger: User taps multiple group chips when `pref_groups_multiselect == true`
  - Input: Set of group UUIDs
  - Process: Sets `_groupFilter` to selected groups; adapter shows entries in ANY selected group
  - Output: Entries matching any selected group shown
  - Error: N/A

- [ ] **FP-A1-FLT-03** Filter entries with no group
  - Trigger: User taps "No group" chip
  - Input: null UUID in filter set
  - Process: Shows entries with empty group set
  - Output: Only ungrouped entries shown
  - Error: N/A

- [ ] **FP-A1-FLT-04** Clear group filter
  - Trigger: User deselects all chips or taps already-selected chip
  - Input: Empty filter set
  - Process: Clears `_groupFilter`; all entries shown
  - Output: Full entry list
  - Error: N/A

- [ ] **FP-A1-FLT-05** Persist group filter across sessions
  - Trigger: Group filter changes
  - Input: Set of UUIDs
  - Process: Saved to `pref_group_filter_uuids` as JSON array
  - Output: Filter restored on next app launch
  - Error: N/A

---

### A2. AuthActivity (Vault Unlock Screen)

- [ ] **FP-A2-ULK-01** Display password input field
  - Trigger: AuthActivity launched (vault is encrypted and locked)
  - Input: Vault file read from disk
  - Process: Shows password TextInputLayout; if `pref_pin_keyboard == true`, shows numeric-only input
  - Output: Password field focused, keyboard shown
  - Error: If vault file cannot be read, shows error dialog and closes

- [ ] **FP-A2-ULK-02** Unlock vault with password
  - Trigger: User enters password and taps "Unlock" button
  - Input: Password char array
  - Process: PasswordSlotDecryptTask derives key via SCrypt, attempts AES-GCM decryption of MasterKey
  - Output: On success, vault loaded and MainActivity shown; on failure, error dialog
  - Error: Wrong password shows "Incorrect password" dialog; after 3 failures, switches to visible password mode

- [ ] **FP-A2-ULK-03** Unlock vault with biometrics
  - Trigger: Biometric button tapped or auto-shown on resume
  - Input: BiometricSlot, SecretKey from Android KeyStore
  - Process: Shows BiometricPrompt; on success, decrypts MasterKey via Cipher from CryptoObject
  - Output: Vault loaded, MainActivity shown
  - Error: Biometric error shows toast; key invalidation shows info box

- [ ] **FP-A2-ULK-04** Auto-show biometric prompt
  - Trigger: AuthActivity resumes and biometric key is available and no password reminder
  - Input: None
  - Process: Automatically calls `showBiometricPrompt()` on first resume (unless inhibited)
  - Output: Biometric prompt dialog
  - Error: N/A

- [ ] **FP-A2-ULK-05** Password reminder popup
  - Trigger: `isPasswordReminderNeeded() == true` (duration since last password entry exceeds configured frequency)
  - Input: Password reminder frequency preference
  - Process: Shows popup near password field; forces password entry instead of biometrics
  - Output: Popup shown; biometric button hidden; password field focused
  - Error: N/A

- [ ] **FP-A2-ULK-06** PIN keyboard mode
  - Trigger: `pref_pin_keyboard == true`
  - Input: Preference value
  - Process: Switches to NoAutofillEditText with numeric input type
  - Output: Numeric keyboard shown for PIN-style passwords
  - Error: N/A

- [ ] **FP-A2-ULK-07** Audit log: failed password unlock
  - Trigger: Wrong password entered
  - Input: Event
  - Process: `_auditLogRepository.addVaultUnlockFailedPasswordEvent()`
  - Output: Event logged to Room DB
  - Error: N/A

- [ ] **FP-A2-ULK-08** Audit log: failed biometric unlock
  - Trigger: Biometric authentication error (not user cancel)
  - Input: Event
  - Process: `_auditLogRepository.addVaultUnlockFailedBiometricsEvent()`
  - Output: Event logged to Room DB
  - Error: N/A

- [ ] **FP-A2-ULK-09** Back press exits app
  - Trigger: User presses back on AuthActivity
  - Input: None
  - Process: `finishAffinity()` called
  - Output: App completely closed
  - Error: N/A

---

### A3. IntroActivity (First-Run Setup)

- [ ] **FP-A3-INT-01** Welcome slide display
  - Trigger: IntroActivity launched
  - Input: None
  - Process: Shows WelcomeSlide with app description and import option
  - Output: Welcome screen
  - Error: N/A

- [ ] **FP-A3-INT-02** Security picker slide
  - Trigger: User advances from welcome
  - Input: None
  - Process: Shows SecurityPickerSlide with options: None, Password only, Password + Biometric
  - Output: Security type selection
  - Error: N/A

- [ ] **FP-A3-INT-03** Security setup slide (password creation)
  - Trigger: User selects Password or Biometric option
  - Input: Password, password confirmation
  - Process: SecuritySetupSlide collects password; creates PasswordSlot with SCrypt; optionally creates BiometricSlot
  - Output: VaultFileCredentials with MasterKey and SlotList stored in state
  - Error: Passwords don't match, password too weak

- [ ] **FP-A3-INT-04** Skip encryption (none selected)
  - Trigger: User selects "None" in security picker
  - Input: None
  - Process: Skips SecuritySetupSlide to DoneSlide; creates vault without credentials
  - Output: Unencrypted vault
  - Error: N/A

- [ ] **FP-A3-INT-05** Done slide and vault initialization
  - Trigger: User reaches DoneSlide and taps "Done"
  - Input: VaultFileCredentials from state
  - Process: `_vaultManager.initNew(creds)` creates empty vault and saves to disk
  - Output: `pref_intro` set to true; MainActivity loads
  - Error: If vault init fails, shows error dialog

- [ ] **FP-A3-INT-06** Import from file during intro
  - Trigger: User taps import button on WelcomeSlide
  - Input: File from picker
  - Process: Reads Aegis vault file; writes to app storage; skips to DoneSlide
  - Output: Vault imported, state marked as `imported=true`
  - Error: If file is invalid, shows error

---

### A4. EditEntryActivity (Add/Edit Entry)

- [ ] **FP-A4-EDT-01** Display entry form fields
  - Trigger: Activity launched with entry UUID (edit) or new entry (add)
  - Input: VaultEntry or default entry
  - Process: Populates issuer, name, secret, type, algorithm, period/counter, digits, pin, note, groups, icon, usage count, last used
  - Output: Form displayed with all fields
  - Error: N/A

- [ ] **FP-A4-EDT-02** Select OTP type from dropdown
  - Trigger: User changes type dropdown
  - Input: Type string (TOTP, HOTP, Steam, mOTP, Yandex)
  - Process: Updates period/counter label, default values for digits/algorithm/period; shows/hides PIN field
  - Output: Form fields updated for selected type
  - Error: N/A

- [ ] **FP-A4-EDT-03** Save entry (new)
  - Trigger: User taps "Save" menu item for a new entry
  - Input: All form field values
  - Process: `parseEntry()` validates and creates VaultEntry; checks for duplicate name+issuer; `vault.addEntry()`; saves vault
  - Output: Entry added to vault; returns to MainActivity
  - Error: Invalid fields show error dialog; duplicate triggers bottom sheet

- [ ] **FP-A4-EDT-04** Save entry (edit existing)
  - Trigger: User taps "Save" for existing entry
  - Input: Modified form values
  - Process: `parseEntry()` creates new VaultEntry; `vault.replaceEntry()`; saves vault
  - Output: Entry updated; returns to MainActivity
  - Error: Invalid fields show error dialog

- [ ] **FP-A4-EDT-05** Delete entry
  - Trigger: User taps "Delete" menu item (edit mode only)
  - Input: Entry UUID
  - Process: Shows confirmation dialog; on confirm, `vault.removeEntry()`; saves vault
  - Output: Entry removed; returns to MainActivity
  - Error: If save fails, shows error

- [ ] **FP-A4-EDT-06** Duplicate entry handling
  - Trigger: New entry has same name+issuer as existing
  - Input: New entry and duplicate entries
  - Process: Shows bottom sheet with options: Overwrite, Add with suffix (#2), Cancel
  - Output: Entry saved according to user choice
  - Error: N/A

- [ ] **FP-A4-EDT-07** Select custom icon from gallery
  - Trigger: User taps icon area
  - Input: Image from gallery/file picker
  - Process: If icon packs exist, shows IconPickerDialog first; otherwise goes to gallery; image loaded into KropView for cropping
  - Output: Cropped image set as entry icon (JPEG/PNG)
  - Error: If image read fails, shows error

- [ ] **FP-A4-EDT-08** Select icon from icon pack
  - Trigger: User taps icon area (icon packs installed)
  - Input: Icon pack, issuer search
  - Process: Shows IconPickerDialog with searchable grid; auto-searches by issuer
  - Output: Selected icon set on entry
  - Error: N/A

- [ ] **FP-A4-EDT-09** Select SVG icon
  - Trigger: User picks SVG file
  - Input: SVG file URI
  - Process: Reads SVG bytes; stores as VaultEntryIcon with SVG type
  - Output: SVG icon displayed and stored
  - Error: If file read fails, shows error

- [ ] **FP-A4-EDT-10** Reset to default (text) icon
  - Trigger: User taps "Default icon" menu item
  - Input: None
  - Process: Clears custom icon; generates TextDrawable from issuer+name
  - Output: Text-based icon displayed
  - Error: N/A

- [ ] **FP-A4-EDT-11** Group selection dialog
  - Trigger: User taps group field
  - Input: Available groups
  - Process: Shows bottom sheet with chip-based group selector; option to add new group inline
  - Output: Selected groups applied to entry
  - Error: N/A

- [ ] **FP-A4-EDT-12** Add new group inline
  - Trigger: User taps "Add group" in group selection dialog
  - Input: Group name text
  - Process: Creates VaultGroup if not existing; adds to vault; selects in chip group
  - Output: New group available and selected
  - Error: Empty name ignored

- [ ] **FP-A4-EDT-13** Advanced settings accordion
  - Trigger: User taps "Advanced settings" header
  - Input: None
  - Process: Animates header fade-out, advanced layout fade-in
  - Output: Advanced fields (secret, algorithm, digits, period, usage count) visible
  - Error: N/A

- [ ] **FP-A4-EDT-14** Reset usage count
  - Trigger: User taps "Reset usage count" menu item
  - Input: Entry UUID
  - Process: Shows confirmation; resets `pref_usage_count[uuid]` to 0
  - Output: Usage count field shows 0
  - Error: N/A

- [ ] **FP-A4-EDT-15** Unsaved changes detection
  - Trigger: User navigates back with unsaved changes
  - Input: Current form state vs original entry
  - Process: Compares parsed entry with original; if different, shows discard dialog (Save/Discard)
  - Output: Dialog shown
  - Error: If entry cannot be parsed, allows discard only

- [ ] **FP-A4-EDT-16** Validate secret encoding
  - Trigger: User enters secret
  - Input: Secret string
  - Process: Base32 decode for most types, Hex decode for mOTP; validates non-empty
  - Output: Valid secret stored
  - Error: Invalid encoding shows parse error

- [ ] **FP-A4-EDT-17** Validate PIN for mOTP/Yandex
  - Trigger: User enters PIN for mOTP or Yandex type
  - Input: PIN string
  - Process: mOTP requires exactly 4 digits; Yandex requires minimum 4 characters
  - Output: Valid PIN stored
  - Error: Invalid PIN length shows error

---

### A5. ScannerActivity (QR Code Scanner)

- [ ] **FP-A5-SCN-01** Camera preview display
  - Trigger: ScannerActivity launched
  - Input: Camera permission
  - Process: CameraX binds preview and ImageAnalysis to lifecycle
  - Output: Live camera feed in PreviewView
  - Error: If no camera available, shows toast and finishes

- [ ] **FP-A5-SCN-02** QR code detection and parsing
  - Trigger: QR code detected in camera frame
  - Input: ZXing Result
  - Process: Parses URI; if `otpauth://`, creates VaultEntry; if `otpauth-migration://`, handles batch export
  - Output: Returns entries to MainActivity
  - Error: Invalid QR shows error dialog with retry

- [ ] **FP-A5-SCN-03** Google Auth migration batch scan
  - Trigger: QR contains `otpauth-migration://` URI
  - Input: Protobuf MigrationPayload
  - Process: Parses batch index; accumulates entries across multiple QR scans; shows progress toast
  - Output: When all batches scanned, returns all entries
  - Error: Out-of-order or mismatched batch shows toast warning

- [ ] **FP-A5-SCN-04** Switch front/back camera
  - Trigger: User taps camera switch icon in toolbar
  - Input: Current lens facing
  - Process: Unbinds current camera, rebinds with opposite lens
  - Output: Camera preview switches
  - Error: Button hidden if device has only one camera

---

### A6. PreferencesActivity & Fragments

- [ ] **FP-A6-PRF-01** Navigate preference sections
  - Trigger: User taps a preference category in MainPreferencesFragment
  - Input: Fragment class
  - Process: Navigates to sub-fragment (Appearance, Behavior, Security, Backups, Import/Export, Icon Packs, Audit Log)
  - Output: Sub-fragment displayed
  - Error: N/A

- [ ] **FP-A6-PRF-02** Change theme (Light/Dark/AMOLED/System/System AMOLED)
  - Trigger: User selects theme in AppearancePreferencesFragment
  - Input: Theme enum value
  - Process: Stores `pref_current_theme`; recreates activity
  - Output: App theme changes
  - Error: N/A

- [ ] **FP-A6-PRF-03** Toggle dynamic colors (Material You)
  - Trigger: User toggles `pref_dynamic_colors`
  - Input: Boolean
  - Process: Enables/disables Material You dynamic theming
  - Output: Color scheme changes
  - Error: N/A

- [ ] **FP-A6-PRF-04** Change view mode (Normal/Compact/Small/Tiles)
  - Trigger: User selects view mode
  - Input: ViewMode enum
  - Process: Stores `pref_current_view_mode`; adapter switches layout (card_entry, card_entry_compact, card_entry_small, card_entry_tile)
  - Output: Entry list layout changes; Tiles mode uses 2-column grid
  - Error: N/A

- [ ] **FP-A6-PRF-05** Change account name position (End/Below/Hidden)
  - Trigger: User selects position
  - Input: AccountNamePosition enum
  - Process: Stores `pref_account_name_position`
  - Output: Account name moved/hidden in entry cards
  - Error: N/A

- [ ] **FP-A6-PRF-06** Toggle show icons
  - Trigger: User toggles `pref_show_icons`
  - Input: Boolean
  - Process: Icons shown/hidden in entry list
  - Output: Icon visibility changes
  - Error: N/A

- [ ] **FP-A6-PRF-07** Toggle tap-to-reveal
  - Trigger: User toggles `pref_tap_to_reveal`
  - Input: Boolean
  - Process: When enabled, OTP codes hidden with bullet characters until tapped
  - Output: Codes hidden/shown
  - Error: N/A

- [ ] **FP-A6-PRF-08** Set tap-to-reveal timeout
  - Trigger: User sets `pref_tap_to_reveal_time`
  - Input: Integer seconds (default 30)
  - Process: Stores value; used as `secondsToFocus` in `focusEntry()`
  - Output: Reveal duration changes
  - Error: N/A

- [ ] **FP-A6-PRF-09** Set copy behavior (Never/Single Tap/Double Tap)
  - Trigger: User selects copy behavior
  - Input: CopyBehavior enum
  - Process: Stores `pref_current_copy_behavior`
  - Output: Copy behavior changes in entry list
  - Error: N/A

- [ ] **FP-A6-PRF-10** Set auto-lock behavior (bitmask)
  - Trigger: User configures auto-lock checkboxes
  - Input: Bitmask of AUTO_LOCK_ON_BACK_BUTTON, AUTO_LOCK_ON_MINIMIZE, AUTO_LOCK_ON_DEVICE_LOCK
  - Process: Stores `pref_auto_lock_mask`
  - Output: Auto-lock triggers change
  - Error: N/A

- [ ] **FP-A6-PRF-11** Set search behavior (bitmask)
  - Trigger: User configures search-in checkboxes
  - Input: Bitmask of SEARCH_IN_ISSUER, SEARCH_IN_NAME, SEARCH_IN_NOTE, SEARCH_IN_GROUPS
  - Process: Stores `pref_search_behavior_mask`
  - Output: Search scope changes
  - Error: N/A

- [ ] **FP-A6-PRF-12** Change language
  - Trigger: User selects language
  - Input: Locale string
  - Process: Stores `pref_lang`; recreates activity with new locale
  - Output: UI language changes
  - Error: N/A

- [ ] **FP-A6-PRF-13** Toggle secure screen
  - Trigger: User toggles `pref_secure_screen`
  - Input: Boolean
  - Process: When enabled, sets `FLAG_SECURE` on all activity windows (prevents screenshots/recent thumbnails)
  - Output: Screen capture blocked/allowed
  - Error: N/A

- [ ] **FP-A6-PRF-14** Set password reminder frequency
  - Trigger: User selects frequency (Never/Weekly/Biweekly/Monthly/Quarterly)
  - Input: PassReminderFreq enum
  - Process: Stores `pref_password_reminder_freq`
  - Output: Password reminder timing changes
  - Error: N/A

- [ ] **FP-A6-PRF-15** Change vault password
  - Trigger: User initiates password change in SecurityPreferencesFragment
  - Input: Current password, new password
  - Process: Verifies current password; derives new key; creates new PasswordSlot; replaces old; saves vault
  - Output: Password changed
  - Error: Wrong current password shows error

- [ ] **FP-A6-PRF-16** Enable/disable biometric unlock
  - Trigger: User toggles biometric in SecurityPreferencesFragment
  - Input: Toggle state
  - Process: Enable: creates BiometricSlot with Android KeyStore key, encrypts MasterKey; Disable: removes BiometricSlot, deletes KeyStore entry
  - Output: Biometric slot added/removed
  - Error: Biometric enrollment required; KeyStore errors

- [ ] **FP-A6-PRF-17** Set backup password
  - Trigger: User sets backup password in SecurityPreferencesFragment
  - Input: New backup password
  - Process: Creates PasswordSlot with `isBackup=true`; adds to slot list
  - Output: Backup password slot added; used in exports instead of regular password
  - Error: N/A

- [ ] **FP-A6-PRF-18** Toggle built-in backups
  - Trigger: User toggles `pref_backups`
  - Input: Boolean
  - Process: Enables/disables automatic backup on vault save
  - Output: Backup behavior changes
  - Error: N/A

- [ ] **FP-A6-PRF-19** Set backup location
  - Trigger: User selects folder/file via SAF picker
  - Input: URI from DocumentsUI
  - Process: Takes persistable URI permission; stores `pref_backups_location`
  - Output: Backup destination set
  - Error: If no permission, shows error

- [ ] **FP-A6-PRF-20** Set backup version count
  - Trigger: User sets number of backup versions to keep
  - Input: Integer (default 5, or infinite=-1)
  - Process: Stores `pref_backups_versions`
  - Output: Old backups pruned according to versioning strategy
  - Error: N/A

- [ ] **FP-A6-PRF-21** Toggle Android backup
  - Trigger: User toggles `pref_android_backups`
  - Input: Boolean
  - Process: Enables Android Backup Manager; `dataChanged()` called on vault saves
  - Output: Android backup system notified
  - Error: N/A

- [ ] **FP-A6-PRF-22** Code grouping setting
  - Trigger: User selects grouping (Halves/None/Twos/Threes/Fours)
  - Input: CodeGrouping enum
  - Process: Stores `pref_code_group_size_string`
  - Output: Code display formatting changes
  - Error: N/A

- [ ] **FP-A6-PRF-23** Toggle highlight entry
  - Trigger: User toggles `pref_highlight_entry`
  - Input: Boolean
  - Process: Enables dimming of unfocused entries
  - Output: Visual highlight behavior changes
  - Error: N/A

- [ ] **FP-A6-PRF-24** Toggle show next code
  - Trigger: User toggles `pref_show_next_code`
  - Input: Boolean
  - Process: Shows/hides next TOTP code below current
  - Output: Next code visibility changes
  - Error: N/A

- [ ] **FP-A6-PRF-25** Toggle expiration state
  - Trigger: User toggles `pref_expiration_state`
  - Input: Boolean
  - Process: Enables/disables color change and blink animation near expiry
  - Output: Expiration visual cues on/off
  - Error: N/A

- [ ] **FP-A6-PRF-26** Toggle minimize on copy
  - Trigger: User toggles `pref_minimize_on_copy`
  - Input: Boolean
  - Process: App minimizes after copying code
  - Output: Behavior change
  - Error: N/A

- [ ] **FP-A6-PRF-27** Toggle group multi-select
  - Trigger: User toggles `pref_groups_multiselect`
  - Input: Boolean
  - Process: ChipGroup switches between single-selection and multi-selection
  - Output: Group filter behavior changes
  - Error: N/A

- [ ] **FP-A6-PRF-28** Toggle only show necessary account names
  - Trigger: User toggles `pref_shared_issuer_account_name`
  - Input: Boolean
  - Process: Hides account name if only one entry exists for that issuer
  - Output: Account name display changes
  - Error: N/A

- [ ] **FP-A6-PRF-29** Manage groups (navigate to GroupManagerActivity)
  - Trigger: User taps "Manage groups" preference
  - Input: None
  - Process: Launches GroupManagerActivity
  - Output: Group manager screen
  - Error: N/A

---

### A7. GroupManagerActivity

- [ ] **FP-A7-GRP-01** Display groups list with drag handles
  - Trigger: Activity launched
  - Input: Groups from vault
  - Process: RecyclerView with GroupAdapter; ItemTouchHelper for drag reorder
  - Output: Reorderable list of groups
  - Error: Empty state shown if no groups

- [ ] **FP-A7-GRP-02** Rename group
  - Trigger: User taps edit on a group
  - Input: Group, new name
  - Process: Shows text input dialog; replaces group with renamed clone
  - Output: Group name updated
  - Error: Empty name ignored

- [ ] **FP-A7-GRP-03** Delete group
  - Trigger: User taps delete on a group
  - Input: Group UUID
  - Process: Shows confirmation; marks group for removal; removes from entries on save
  - Output: Group removed from list
  - Error: N/A

- [ ] **FP-A7-GRP-04** Delete unused groups
  - Trigger: User taps "Delete unused groups" menu item
  - Input: All groups, used groups
  - Process: Finds groups not assigned to any entry; removes all of them
  - Output: Unused groups removed
  - Error: N/A

- [ ] **FP-A7-GRP-05** Reorder groups via drag-and-drop
  - Trigger: User drags a group
  - Input: Source and target positions
  - Process: Swaps group positions in adapter
  - Output: Group order updated
  - Error: N/A

- [ ] **FP-A7-GRP-06** Save group changes
  - Trigger: User taps save menu item
  - Input: Modified groups list, removed group UUIDs
  - Process: `vault.removeGroup()` for each removed; `vault.replaceGroups()` for order; saves vault
  - Output: Changes persisted
  - Error: If save fails, shows error

---

### A8. TransferEntriesActivity

- [ ] **FP-A8-TRN-01** Display QR code for entry
  - Trigger: Activity launched with entries
  - Input: List of Transferable (GoogleAuthInfo or Export)
  - Process: Encodes entry URI to QR bitmap via ZXing
  - Output: QR code image with issuer/account name; next/previous buttons for multi-entry
  - Error: If QR generation fails, shows error dialog

- [ ] **FP-A8-TRN-02** Navigate between QR codes
  - Trigger: User taps Next/Previous buttons
  - Input: Current index
  - Process: Advances/retreats in entries list; regenerates QR
  - Output: Updated QR code and labels
  - Error: N/A

- [ ] **FP-A8-TRN-03** Copy URI to clipboard
  - Trigger: User taps "Copy" button
  - Input: Entry URI
  - Process: Copies `otpauth://` URI to clipboard with sensitive flag
  - Output: Toast confirmation
  - Error: If URI generation fails, shows error

- [ ] **FP-A8-TRN-04** Toggle screen brightness
  - Trigger: User taps QR image
  - Input: None
  - Process: Toggles between max brightness and system brightness
  - Output: Screen brightness changes for QR readability
  - Error: N/A

---

### A9. ImportEntriesActivity

- [ ] **FP-A9-IMP-01** Select importer from list
  - Trigger: Activity launched
  - Input: List of 19 DatabaseImporter definitions
  - Process: Shows dialog with importers; some require root access, some accept file
  - Output: Selected importer and file/root mode
  - Error: N/A

- [ ] **FP-A9-IMP-02** Import from file
  - Trigger: User picks file for selected importer
  - Input: File URI, importer class
  - Process: `DatabaseImporter.read(inputStream)` parses entries; shows list with checkboxes
  - Output: ImportEntriesActivity shows parseable entries
  - Error: If file is encrypted (e.g., andOTP), prompts for password; parse errors shown per entry

- [ ] **FP-A9-IMP-03** Import from rooted device (direct app data)
  - Trigger: User selects importer with root support
  - Input: Root shell, app data path
  - Process: `DatabaseImporter.readFromApp(shell)` uses libsu to access other app's data
  - Output: Entries extracted
  - Error: Root not available; app not installed; data access fails

- [ ] **FP-A9-IMP-04** Select/deselect entries for import
  - Trigger: User checks/unchecks entries in import list
  - Input: Entry selection state
  - Process: Updates selection in ImportEntriesAdapter
  - Output: Import count updated
  - Error: N/A

- [ ] **FP-A9-IMP-05** Confirm import and add entries to vault
  - Trigger: User taps import button
  - Input: Selected entries
  - Process: Each entry added to vault via `vault.addEntry()`; groups migrated if needed; vault saved
  - Output: Entries appear in main list
  - Error: If save fails, shows error

---

### A10. AboutActivity & LicensesActivity

- [ ] **FP-A10-ABT-01** Display app version and build info
  - Trigger: AboutActivity launched
  - Input: BuildConfig values
  - Process: Shows version name, version code, build type
  - Output: About screen with app info
  - Error: N/A

- [ ] **FP-A10-ABT-02** Display open source licenses
  - Trigger: User taps licenses link
  - Input: None
  - Process: Launches LicensesActivity showing WebView with license text
  - Output: Licenses displayed
  - Error: N/A

---

### A11. AssignIconsActivity

- [ ] **FP-A11-ICN-01** Batch assign icons from icon pack
  - Trigger: Activity launched with entry UUIDs
  - Input: Entries and icon packs
  - Process: Matches entries to icons by issuer name; shows suggested assignments
  - Output: Grid of entries with suggested icons
  - Error: No matching icons found

- [ ] **FP-A11-ICN-02** Confirm icon assignments
  - Trigger: User taps save
  - Input: Entry-to-icon mapping
  - Process: Updates each entry's icon; saves vault
  - Output: Icons updated on entries
  - Error: If save fails, shows error

---

## B. Data Layer Feature Points

### B1. Vault File Operations

- [ ] **FP-B1-VLT-01** Read vault file from disk
  - Trigger: App launch, auth complete
  - Input: `aegis.json` file path
  - Process: `AtomicFile.readFully()`, parse JSON via `VaultFile.fromBytes()`
  - Output: VaultFile object with header and content
  - Error: IOException, VaultFileException on corrupt file

- [ ] **FP-B1-VLT-02** Write vault file to disk (atomic)
  - Trigger: Any vault modification (add/edit/delete/reorder)
  - Input: Vault JSON bytes
  - Process: `AtomicFile.startWrite()`, write bytes, `finishWrite()`; on error `failWrite()`
  - Output: `aegis.json` atomically updated
  - Error: IOException triggers failWrite to prevent corruption

- [ ] **FP-B1-VLT-03** Encrypt vault content (AES-256-GCM)
  - Trigger: Vault save when encryption enabled
  - Input: Vault JSON, MasterKey
  - Process: `MasterKey.encrypt()` with AES-GCM; Base64 encode ciphertext; store with header (slots + params)
  - Output: Encrypted `db` field in vault file
  - Error: MasterKeyException on crypto failure

- [ ] **FP-B1-VLT-04** Decrypt vault content (AES-256-GCM)
  - Trigger: Auth success
  - Input: Base64 ciphertext, MasterKey, CryptParameters (nonce, tag)
  - Process: `MasterKey.decrypt()` with AES-GCM
  - Output: Decrypted JSON, parsed to Vault object
  - Error: Bad padding (wrong key) throws SlotIntegrityException

- [ ] **FP-B1-VLT-05** Parse vault JSON to in-memory objects
  - Trigger: After decryption or plain read
  - Input: JSONObject
  - Process: `Vault.fromJson()` parses entries and groups; `VaultEntry.fromJson()` parses each entry with OtpInfo
  - Output: UUIDMap of VaultEntry, UUIDMap of VaultGroup
  - Error: VaultException on version mismatch or parse error

- [ ] **FP-B1-VLT-06** Serialize vault to JSON
  - Trigger: Before encryption or plain write
  - Input: Vault object
  - Process: `Vault.toJson()` serializes entries and groups; optional EntryFilter for exports
  - Output: JSONObject
  - Error: N/A

- [ ] **FP-B1-VLT-07** Delete vault file
  - Trigger: Panic trigger
  - Input: None
  - Process: `VaultRepository.deleteFile()` via `AtomicFile.delete()`
  - Output: `aegis.json` deleted
  - Error: N/A

- [ ] **FP-B1-VLT-08** Check vault file exists
  - Trigger: App startup routing
  - Input: None
  - Process: `VaultRepository.fileExists()` checks file existence
  - Output: Boolean
  - Error: N/A

### B2. Encryption Key Management

- [ ] **FP-B2-KEY-01** Generate MasterKey
  - Trigger: New vault creation
  - Input: None
  - Process: `MasterKey.generate()` creates random AES-256 key
  - Output: MasterKey object
  - Error: N/A

- [ ] **FP-B2-KEY-02** Password key derivation (SCrypt)
  - Trigger: Password unlock or password change
  - Input: Password char[], SCryptParameters (n=32768, r=8, p=1, salt=32 bytes)
  - Process: `CryptoUtils.deriveKey()` runs SCrypt, produces SecretKey
  - Output: 256-bit derived key
  - Error: Computation-heavy; runs in PasswordSlotDecryptTask background thread

- [ ] **FP-B2-KEY-03** Encrypt MasterKey with derived key
  - Trigger: Slot creation
  - Input: MasterKey, derived SecretKey
  - Process: AES-GCM encrypt MasterKey bytes with derived key; store encrypted key + params in slot
  - Output: PasswordSlot with encrypted MasterKey
  - Error: SlotException on crypto error

- [ ] **FP-B2-KEY-04** Decrypt MasterKey from PasswordSlot
  - Trigger: Password unlock
  - Input: Derived key, encrypted MasterKey, CryptParameters
  - Process: AES-GCM decrypt; verify integrity via GCM tag
  - Output: MasterKey on success
  - Error: SlotIntegrityException (wrong password), SlotException (other error)

- [ ] **FP-B2-KEY-05** Decrypt MasterKey from BiometricSlot
  - Trigger: Biometric unlock success
  - Input: Cipher from BiometricPrompt CryptoObject
  - Process: AES-GCM decrypt encrypted MasterKey using KeyStore-backed cipher
  - Output: MasterKey
  - Error: SlotIntegrityException, SlotException

- [ ] **FP-B2-KEY-06** Store biometric key in Android KeyStore
  - Trigger: Biometric slot setup
  - Input: BiometricSlot UUID as alias
  - Process: `KeyStoreHandle` generates AES key in AndroidKeyStore with user-auth requirement
  - Output: Key stored in hardware-backed keystore
  - Error: KeyStoreHandleException

- [ ] **FP-B2-KEY-07** Remove biometric key from KeyStore
  - Trigger: Biometric disable or encryption disable
  - Input: Key alias
  - Process: `KeyStoreHandle.clear()` or delete specific alias
  - Output: Key removed
  - Error: KeyStoreHandleException (ignored for cleanup)

- [ ] **FP-B2-KEY-08** Detect invalidated biometric key
  - Trigger: AuthActivity checks KeyStore entries
  - Input: BiometricSlot UUID
  - Process: `handle.getKey(id)` returns null if key permanently invalidated (e.g., new fingerprint enrolled)
  - Output: Shows info message about re-enabling biometrics
  - Error: N/A

### B3. Export Operations

- [ ] **FP-B3-EXP-01** Export vault as encrypted JSON
  - Trigger: User exports from ImportExportPreferencesFragment
  - Input: Vault, credentials
  - Process: `vault.export(stream, creds)` serializes and encrypts; backup password slot used if available
  - Output: Encrypted .json file written to chosen location
  - Error: IOException, VaultRepositoryException

- [ ] **FP-B3-EXP-02** Export vault as plain JSON
  - Trigger: User exports without encryption
  - Input: Vault
  - Process: `vault.export(stream, null)` serializes without encryption
  - Output: Plain .json file
  - Error: IOException

- [ ] **FP-B3-EXP-03** Export vault as Google Auth URIs
  - Trigger: User selects URI export format
  - Input: Vault entries
  - Process: `vault.exportGoogleUris()` converts each entry to `otpauth://` URI, one per line
  - Output: Text file with URIs
  - Error: IOException

- [ ] **FP-B3-EXP-04** Export vault as HTML with QR codes
  - Trigger: User selects HTML export format
  - Input: Vault entries
  - Process: `vault.exportHtml()` via VaultHtmlExporter generates HTML with embedded QR code images
  - Output: HTML file with printable QR codes
  - Error: WriterException for QR generation

- [ ] **FP-B3-EXP-05** Filtered export (selected entries only)
  - Trigger: User exports with EntryFilter
  - Input: Filter predicate, entries
  - Process: `vault.exportFiltered()` applies filter before serialization
  - Output: File with only selected entries
  - Error: N/A

### B4. Audit Log (Room DB)

- [ ] **FP-B4-AUD-01** Log vault unlock event
  - Trigger: Successful vault unlock
  - Input: EventType.VAULT_UNLOCKED
  - Process: `AuditLogRepository.addVaultUnlockedEvent()` inserts to Room
  - Output: Audit log entry persisted
  - Error: N/A

- [ ] **FP-B4-AUD-02** Log backup created event
  - Trigger: Backup file written
  - Input: EventType.VAULT_BACKUP_CREATED
  - Process: Insert to Room
  - Output: Logged
  - Error: N/A

- [ ] **FP-B4-AUD-03** Log vault exported event
  - Trigger: Export completed
  - Input: EventType.VAULT_EXPORTED
  - Process: Insert to Room
  - Output: Logged
  - Error: N/A

- [ ] **FP-B4-AUD-04** Log entry shared event
  - Trigger: Entry shared via QR
  - Input: EventType.ENTRY_SHARED with reference (issuer:name)
  - Process: Insert to Room
  - Output: Logged with reference
  - Error: N/A

- [ ] **FP-B4-AUD-05** Display audit log
  - Trigger: User opens AuditLogPreferencesFragment
  - Input: LiveData from `auditLogDao.getAll()` (last 30 days, DESC)
  - Process: RecyclerView with AuditLogAdapter
  - Output: List of audit events with timestamps
  - Error: N/A

---

## C. Service & Business Logic Feature Points

### C1. OTP Generation

- [ ] **FP-C1-OTP-01** TOTP code generation
  - Trigger: Entry display, timer expiry
  - Input: Secret (byte[]), algorithm (SHA1/SHA256/SHA512), digits (6-10), period (default 30s), current time
  - Process: `TOTP.generateOTP()` computes HMAC-based TOTP per RFC 6238; truncates to digits
  - Output: Numeric string of specified digit count
  - Error: Empty secret throws OtpInfoException ("ERROR" displayed)

- [ ] **FP-C1-OTP-02** HOTP code generation
  - Trigger: Entry display, refresh button tap
  - Input: Secret, algorithm, digits, counter (long)
  - Process: `HOTP.generateOTP()` computes HMAC-based HOTP per RFC 4226
  - Output: Numeric string
  - Error: Empty secret throws OtpInfoException

- [ ] **FP-C1-OTP-03** Steam Guard code generation
  - Trigger: Entry display, timer expiry
  - Input: Secret, period (default 30s)
  - Process: `TOTP.generateOTP()` then `otp.toSteamString()` using Steam alphabet (23456789BCDFGHJKMNPQRTVWXY), 5 chars
  - Output: 5-character alphanumeric Steam code
  - Error: Empty secret

- [ ] **FP-C1-OTP-04** mOTP code generation
  - Trigger: Entry display, timer expiry
  - Input: Secret (hex), PIN (4 digits), period (10s), algorithm (MD5)
  - Process: `MOTP.generateOTP()` concatenates epoch/10 + secret_hex + PIN, MD5 hashes, takes first 6 hex chars
  - Output: 6-character hex code
  - Error: PIN not set throws IllegalStateException

- [ ] **FP-C1-OTP-05** Yandex OTP code generation
  - Trigger: Entry display, timer expiry
  - Input: Secret (16 or 26 bytes with checksum), PIN, algorithm (SHA256), period (30s), digits (8)
  - Process: `YAOTP.generateOTP()` with custom Yandex algorithm; validates secret checksum for 26-byte secrets
  - Output: 8-character code
  - Error: Invalid secret length; bad checksum; PIN not set

- [ ] **FP-C1-OTP-06** HOTP counter increment
  - Trigger: User taps refresh button on HOTP entry
  - Input: Current counter
  - Process: `HotpInfo.incrementCounter()` adds 1; vault saved
  - Output: Counter updated, new code generated
  - Error: Counter overflow (extremely unlikely)

### C2. URI Parsing

- [ ] **FP-C2-URI-01** Parse otpauth:// URI
  - Trigger: QR scan, manual import, shared text
  - Input: URI string
  - Process: `GoogleAuthInfo.parseUri()` extracts scheme, type, secret, issuer, name, algorithm, digits, period/counter
  - Output: GoogleAuthInfo with OtpInfo, account name, issuer
  - Error: GoogleAuthInfoException for malformed URIs

- [ ] **FP-C2-URI-02** Parse otpauth-migration:// URI
  - Trigger: Google Auth export QR scan
  - Input: URI with protobuf data
  - Process: `GoogleAuthInfo.parseExportUri()` decodes Base64 protobuf, parses MigrationPayload
  - Output: Export object with list of GoogleAuthInfo and batch metadata
  - Error: Invalid protobuf, unsupported algorithm/type

- [ ] **FP-C2-URI-03** Parse motp:// URI
  - Trigger: mOTP URI encountered
  - Input: URI with hex secret
  - Process: Extracts secret via hex decode
  - Output: MotpInfo
  - Error: Bad hex encoding

- [ ] **FP-C2-URI-04** Generate otpauth:// URI from entry
  - Trigger: Share entry, transfer, export
  - Input: VaultEntry
  - Process: `GoogleAuthInfo.getUri()` builds URI with all parameters
  - Output: URI string
  - Error: Unsupported OtpInfo type

### C3. Backup Management

- [ ] **FP-C3-BAK-01** Auto-backup on vault save
  - Trigger: `saveAndBackup()` called and backups enabled
  - Input: Vault data, backup location URI
  - Process: Exports vault to temp file; `VaultBackupManager.scheduleBackup()` copies to location on background thread
  - Output: Backup file at configured location
  - Error: Permission error, IO error; stores BackupResult with error

- [ ] **FP-C3-BAK-02** Backup versioning (multiple files)
  - Trigger: Backup to directory (tree URI)
  - Input: Temp file, directory URI, versions to keep
  - Process: Creates file with timestamp name `aegis-backup-YYYYMMDD-HHmmss.json`; prunes old backups beyond version limit
  - Output: New backup file; old files deleted
  - Error: File creation failure; permission error

- [ ] **FP-C3-BAK-03** Single-file backup
  - Trigger: Backup to specific file URI
  - Input: Temp file, file URI
  - Process: Overwrites existing file content
  - Output: Updated backup file
  - Error: Permission error, IO error

- [ ] **FP-C3-BAK-04** Backup reminder tracking
  - Trigger: Vault modified without backup
  - Input: None
  - Process: Sets `pref_backups_reminder_needed = true` if no backup method active
  - Output: Error card shown in main list
  - Error: N/A

---

## D. Background & Scheduled Feature Points

- [ ] **FP-D1-LCK-01** Auto-lock on back button
  - Trigger: Back pressed in MainActivity and `AUTO_LOCK_ON_BACK_BUTTON` enabled
  - Input: None
  - Process: `_vaultManager.lock(true)` called
  - Output: Vault locked, all activities finished
  - Error: N/A

- [ ] **FP-D1-LCK-02** Auto-lock on minimize
  - Trigger: App enters background (ON_STOP lifecycle) and `AUTO_LOCK_ON_MINIMIZE` enabled
  - Input: ProcessLifecycleOwner event
  - Process: AppLifecycleObserver detects pause; if not blocked (e.g., file picker), calls lock
  - Output: Vault locked
  - Error: N/A (block mechanism prevents lock during file pickers)

- [ ] **FP-D1-LCK-03** Auto-lock on device lock (screen off)
  - Trigger: SCREEN_OFF broadcast and `AUTO_LOCK_ON_DEVICE_LOCK` enabled
  - Input: Intent.ACTION_SCREEN_OFF
  - Process: VaultLockReceiver receives broadcast; calls `_vaultManager.lock(false)`
  - Output: Vault locked
  - Error: N/A

- [ ] **FP-D1-LCK-04** Block auto-lock during external activities
  - Trigger: Before launching file picker or other external activity
  - Input: None
  - Process: `_vaultManager.setBlockAutoLock(true)` prevents ON_STOP lock; reset on resume
  - Output: Auto-lock suppressed
  - Error: N/A

- [ ] **FP-D1-LCK-05** Orphan activity detection
  - Trigger: Activity resumes after vault was locked externally
  - Input: savedInstanceState
  - Process: `isOrphan()` checks if vault is not loaded and this is not MainActivity/Auth/Intro
  - Output: Redirects to MainActivity
  - Error: N/A

---

## E. Platform Integration Feature Points

- [ ] **FP-E1-CAM-01** Camera permission request
  - Trigger: User taps scan QR action
  - Input: None
  - Process: Checks/requests `CAMERA` permission
  - Output: Permission granted or denied
  - Error: If denied, shows explanation toast

- [ ] **FP-E1-BIO-01** Biometric availability check
  - Trigger: AuthActivity or SecurityPreferencesFragment
  - Input: None
  - Process: `BiometricsHelper.isAvailable()` checks API level, hardware, and enrolled biometrics
  - Output: Boolean
  - Error: N/A

- [ ] **FP-E1-BIO-02** BiometricPrompt for vault unlock
  - Trigger: Biometric button tap or auto-show
  - Input: CryptoObject with AES-GCM cipher from KeyStore
  - Process: `BiometricPrompt.authenticate(info, cryptoObject)`
  - Output: Authentication result with decrypted cipher
  - Error: Error codes for various failure types

- [ ] **FP-E1-CLB-01** Copy to clipboard with sensitive flag
  - Trigger: OTP code copy
  - Input: Code string
  - Process: `ClipboardManager.setPrimaryClip()` with `ClipDescription.EXTRA_IS_SENSITIVE` for API 24+
  - Output: Code in clipboard; auto-clears on API 33+ in 1 minute
  - Error: N/A

- [ ] **FP-E1-SHR-01** Share entry via QR code
  - Trigger: Share from action mode
  - Input: Entry
  - Process: Generates QR code bitmap via ZXing; displays in TransferEntriesActivity
  - Output: QR code visible for scanning
  - Error: QR generation failure

- [ ] **FP-E1-QR-01** QR code scanning via CameraX
  - Trigger: ScannerActivity opened
  - Input: Camera frames
  - Process: `QrCodeAnalyzer` uses ZXing to decode QR from ImageProxy
  - Output: Decoded QR content string
  - Error: No QR found (continuous analysis)

- [ ] **FP-E1-QR-02** QR code decoding from image file
  - Trigger: User picks image for QR scan
  - Input: Image URI
  - Process: `QrDecodeTask` loads bitmap, uses ZXing MultiFormatReader
  - Output: Decoded content
  - Error: No QR code found in image

- [ ] **FP-E1-SEC-01** FLAG_SECURE on all windows
  - Trigger: `pref_secure_screen == true` (default)
  - Input: None
  - Process: `getWindow().addFlags(FLAG_SECURE)` in AegisActivity.onCreate
  - Output: Screenshots and recent preview blocked
  - Error: N/A

---

## F. Initialization & Wiring Feature Points

- [ ] **FP-F1-APP-01** Application initialization
  - Trigger: App process start
  - Input: None
  - Process: AegisApplication extends AegisApplicationBase; Hilt DI; VaultManager, AuditLogRepository, Preferences created; VaultLockReceiver registered for SCREEN_OFF; AppLifecycleObserver registered; cache dir cleared; app shortcuts initialized
  - Output: Application ready
  - Error: N/A

- [ ] **FP-F1-APP-02** Dagger Hilt dependency injection
  - Trigger: App start
  - Input: AegisModule provides VaultManager, AuditLogRepository, AppDatabase, Preferences
  - Process: Singletons created and injected into Activities/Fragments
  - Output: Dependencies available
  - Error: N/A

- [ ] **FP-F1-APP-03** Room database initialization (audit log)
  - Trigger: First access to AuditLogRepository
  - Input: None
  - Process: Room.databaseBuilder for AppDatabase; creates `audit_logs` table
  - Output: Database ready for audit logging
  - Error: N/A

- [ ] **FP-F1-APP-04** Vault file routing on launch
  - Trigger: MainActivity.onResume
  - Input: Vault file existence, loaded state, intro state
  - Process: If `isVaultInitNeeded()` -> IntroActivity; if vault file exists but not loaded -> AuthActivity; if loaded -> show entries
  - Output: Correct screen shown
  - Error: N/A

- [ ] **FP-F1-APP-05** Icon optimization on first load
  - Trigger: Vault loaded and `areIconsOptimized() == false`
  - Input: All entry icons
  - Process: `IconOptimizationTask` optimizes icons (e.g., JPEG compression); sets flag
  - Output: Icons optimized, flag set
  - Error: N/A

- [ ] **FP-F1-APP-06** Group migration from old format
  - Trigger: Vault loaded with old `group` string field on entries
  - Input: Old group strings
  - Process: `Vault.migrateOldGroup()` creates VaultGroup for each unique string, assigns UUIDs
  - Output: Groups migrated to UUID-based system; `isGroupsMigrationFresh()` returns true
  - Error: N/A

---

## G. UI Detail Feature Points

- [ ] **FP-G1-VIS-01** Four view mode layouts
  - Trigger: ViewMode preference set
  - Input: ViewMode (NORMAL, COMPACT, SMALL, TILES)
  - Process: EntryAdapter returns different layout resource: `card_entry`, `card_entry_compact`, `card_entry_small`, `card_entry_tile`; TILES uses 2-column GridLayoutManager
  - Output: Different card densities; COMPACT has 1dp spacing, TILES has 4dp
  - Error: N/A

- [ ] **FP-G1-VIS-02** Text drawable icon generation
  - Trigger: Entry has no custom icon
  - Input: Issuer string, name string
  - Process: `TextDrawableHelper.generate()` creates colored circle with first letter(s)
  - Output: Material-style letter icon
  - Error: N/A

- [ ] **FP-G1-VIS-03** Glide icon loading pipeline
  - Trigger: Entry icon needs display
  - Input: VaultEntryIcon bytes
  - Process: Custom Glide module loads JPEG/PNG/SVG from byte arrays; SVG decoded via custom decoder
  - Output: Icon displayed in ImageView
  - Error: Fallback to text drawable

- [ ] **FP-G1-VIS-04** Entry copied animation
  - Trigger: OTP code copied
  - Input: None
  - Process: Slide-down animation shows "Copied" text over description; fades out after 3s
  - Output: Visual copy confirmation
  - Error: N/A

- [ ] **FP-G1-VIS-05** Entry selection animation
  - Trigger: Entry selected/deselected in action mode
  - Input: Selection state
  - Process: Scale-in/out animation on check mark overlay; card checked state toggle
  - Output: Visual selection indicator
  - Error: N/A

- [ ] **FP-G1-VIS-06** FAB scroll hide behavior
  - Trigger: User scrolls entry list
  - Input: Scroll direction
  - Process: FabScrollHelper hides FAB on scroll down, shows on scroll up
  - Output: FAB visibility animation
  - Error: N/A

- [ ] **FP-G1-VIS-07** TOTP progress bar animation
  - Trigger: TOTP entry with non-uniform period
  - Input: Period, current time
  - Process: `TotpProgressBar` animates countdown
  - Output: Visual countdown indicator
  - Error: N/A

- [ ] **FP-G1-VIS-08** DPad/keyboard navigation support
  - Trigger: D-pad pressed (Android TV or physical keyboard)
  - Input: Key events
  - Process: Detects D-pad press; enables temporary highlight for focused entry
  - Output: Current entry highlighted
  - Error: N/A

---

## P3 - HarmonyOS Incompatible Features

- [ ] **FP-P3-QST-01** Quick Settings tiles (LaunchAppTileService, LaunchScannerTileService)
  - Trigger: QS tile tapped
  - Reason: No QS tile API in HarmonyOS NEXT
  - Priority: P3

- [ ] **FP-P3-PNK-01** Panic trigger (PanicResponderActivity)
  - Trigger: Guardian Project panic intent
  - Reason: No TrustedIntents/Guardian Project support on HarmonyOS
  - Priority: P3

- [ ] **FP-P3-ROOT-01** Root shell import (libsu)
  - Trigger: Import from rooted device
  - Reason: No root/su concept on HarmonyOS
  - Priority: P3

- [ ] **FP-P3-ABKP-01** Android Backup Agent (AegisBackupAgent)
  - Trigger: Android backup service
  - Reason: No Android Backup Manager on HarmonyOS
  - Priority: P3

- [ ] **FP-P3-NOTIF-01** Persistent notification service (NotificationService)
  - Trigger: Vault unlocked
  - Reason: Currently disabled in source; would need HarmonyOS notification adaptation
  - Priority: P3

- [ ] **FP-P3-KS-01** Android KeyStore for biometric slot
  - Trigger: Biometric slot creation/usage
  - Reason: Must use @kit.UserAuthenticationKit on HarmonyOS instead of Android KeyStore + BiometricPrompt
  - Priority: P2 (achievable with HarmonyOS API replacement)

---

## Feature Point Summary Table

| Category | Sub-Category | Count |
|----------|-------------|-------|
| A1. MainActivity | Navigation | 11 |
| A1. MainActivity | Data Display | 13 |
| A1. MainActivity | Interaction | 19 |
| A1. MainActivity | Menu | 11 |
| A1. MainActivity | Filter | 5 |
| A2. AuthActivity | Unlock | 9 |
| A3. IntroActivity | Setup | 6 |
| A4. EditEntryActivity | Edit | 17 |
| A5. ScannerActivity | Scan | 4 |
| A6. Preferences | Settings | 29 |
| A7. GroupManager | Groups | 6 |
| A8. TransferEntries | Transfer | 4 |
| A9. ImportEntries | Import | 5 |
| A10. About | Info | 2 |
| A11. AssignIcons | Icons | 2 |
| B1. Vault File | File Ops | 8 |
| B2. Encryption | Key Mgmt | 8 |
| B3. Export | Export | 5 |
| B4. Audit Log | Logging | 5 |
| C1. OTP | Generation | 6 |
| C2. URI | Parsing | 4 |
| C3. Backup | Management | 4 |
| D1. Auto-Lock | Background | 5 |
| E1. Platform | Integration | 8 |
| F1. Init | Wiring | 6 |
| G1. UI Details | Visual | 8 |
| P3. Incompatible | Android-only | 6 |
| **TOTAL** | | **215** |

---

## Conversion Priority Matrix

### P0 - Critical (Must have for basic functionality)
| ID Range | Feature Area | Count | Notes |
|----------|-------------|-------|-------|
| FP-A1-DSP-01 to -03 | Entry list + OTP codes + TOTP refresh | 3 | Core value proposition |
| FP-A1-INT-01 | Copy OTP on tap | 1 | Primary use case |
| FP-A1-INT-16 | HOTP refresh | 1 | Counter-based OTP must work |
| FP-A1-MNU-10 | Lock vault | 1 | Security essential |
| FP-A2-ULK-01, -02 | Password unlock | 2 | Vault must be unlockable |
| FP-A3-INT-01 to -05 | Intro/setup | 5 | First-run must work |
| FP-A4-EDT-01 to -05 | Add/edit/delete entry | 5 | Entry CRUD |
| FP-B1-VLT-01 to -06 | Vault file read/write/encrypt/decrypt | 6 | Data persistence |
| FP-B2-KEY-01 to -04 | MasterKey + SCrypt + Slot decrypt | 4 | Encryption stack |
| FP-C1-OTP-01 to -06 | All 5 OTP types + HOTP increment | 6 | Code generation |
| FP-C2-URI-01 | Parse otpauth:// URI | 1 | Standard URI format |
| FP-F1-APP-01, -04 | App init + vault routing | 2 | App must start correctly |
| **P0 Total** | | **37** | |

### P1 - Important (Core UX, needed for usable product)
| ID Range | Feature Area | Count | Notes |
|----------|-------------|-------|-------|
| FP-A1-DSP-04 to -07 | Icons, favorites, chips, footer | 4 | UI completeness |
| FP-A1-INT-02 to -05 | Double-tap, reveal, highlight, pause | 4 | UX behaviors |
| FP-A1-INT-06 to -10 | Action mode (select, copy, delete, favorite) | 5 | Multi-select |
| FP-A1-INT-15 | Drag-and-drop reorder | 1 | Custom sort |
| FP-A1-MNU-01 to -09 | Search + all sort modes | 9 | Search & sort |
| FP-A1-FLT-01 to -05 | Group filtering | 5 | Group system |
| FP-A4-EDT-11, -12 | Group selection in editor | 2 | Group assignment |
| FP-A4-EDT-15, -16, -17 | Validation, unsaved changes | 3 | Editor robustness |
| FP-A6-PRF-02 to -14 | Theme, view mode, behavior prefs | 13 | Settings |
| FP-B3-EXP-01 to -02 | Export encrypted/plain JSON | 2 | Data portability |
| FP-C2-URI-04 | Generate URI from entry | 1 | Share/export |
| FP-F1-APP-02, -05, -06 | DI, icon optimization, group migration | 3 | Infrastructure |
| FP-G1-VIS-01 to -04 | View modes, icons, animations | 4 | Visual polish |
| **P1 Total** | | **56** | |

### P2 - Desirable (Full feature parity)
| ID Range | Feature Area | Count | Notes |
|----------|-------------|-------|-------|
| FP-A1-DSP-08 to -13 | Error cards, next code, grouping, expiration | 6 | Advanced display |
| FP-A1-INT-11 to -14 | Share QR, assign icons/groups from action mode | 4 | Action mode extras |
| FP-A1-INT-17 to -19 | Minimize, haptic, usage count | 3 | UX polish |
| FP-A1-MNU-11 | FAB menu | 1 | Add entry UX |
| FP-A1-NAV-09 to -11 | Intent handling, image scan | 3 | Deep linking |
| FP-A2-ULK-03 to -08 | Biometric unlock, PIN mode, audit | 6 | Biometric (needs HarmonyOS API) |
| FP-A3-INT-06 | Import during intro | 1 | Convenience |
| FP-A4-EDT-06 to -10, -13, -14 | Duplicate, icons, accordion, reset | 7 | Editor features |
| FP-A5-SCN-01 to -04 | QR scanner (needs HarmonyOS ScanKit) | 4 | QR scanning |
| FP-A6-PRF-15 to -28 | Security, backup, advanced prefs | 14 | Full preferences |
| FP-A7-GRP-01 to -06 | Group manager | 6 | Group management |
| FP-A8-TRN-01 to -04 | Transfer/share QR | 4 | Entry sharing |
| FP-A9-IMP-01 to -05 | Import from other apps | 5 | Import system |
| FP-A10-ABT-01, -02 | About screen | 2 | Info |
| FP-A11-ICN-01, -02 | Batch icon assign | 2 | Icon management |
| FP-B2-KEY-05 to -08 | Biometric slot management | 4 | Biometric key ops |
| FP-B3-EXP-03 to -05 | URI/HTML export, filtered export | 3 | Export formats |
| FP-B4-AUD-01 to -05 | Audit log | 5 | Security auditing |
| FP-C2-URI-02, -03 | Migration URI, mOTP URI | 2 | URI format support |
| FP-C3-BAK-01 to -04 | Auto-backup, versioning, reminders | 4 | Backup system |
| FP-D1-LCK-01 to -05 | Auto-lock triggers | 5 | Security |
| FP-E1-*-* | Platform integration | 8 | Platform APIs |
| FP-F1-APP-03 | Room DB init | 1 | Audit DB |
| FP-G1-VIS-05 to -08 | Animations, scroll behavior | 4 | Visual polish |
| **P2 Total** | | **104** | |

### P3 - Not Applicable (Cannot work on HarmonyOS)
| ID | Feature | Reason |
|----|---------|--------|
| FP-P3-QST-01 | Quick Settings tiles | No QS tile API |
| FP-P3-PNK-01 | Panic trigger | No Guardian Project/TrustedIntents |
| FP-P3-ROOT-01 | Root shell import | No root concept |
| FP-P3-ABKP-01 | Android Backup Agent | No Android backup service |
| FP-P3-NOTIF-01 | Persistent notification | Disabled in source; needs rework |
| FP-P3-KS-01 | Android KeyStore biometric | Replace with @kit.UserAuthenticationKit |
| **P3 Total** | | **6** |

---

## Key Implementation Notes for HarmonyOS Conversion

1. **Vault File**: The JSON-based vault file with AES-GCM encryption is platform-agnostic. The crypto primitives (AES-GCM, SCrypt, HMAC-SHA) are available in HarmonyOS via @ohos.security.cryptoFramework.

2. **OTP Algorithms**: All OTP generation (TOTP/HOTP/Steam/mOTP/Yandex) uses standard crypto (HMAC-SHA1/SHA256/SHA512, MD5). These are available in HarmonyOS crypto API.

3. **Biometric Unlock**: Replace Android KeyStore + BiometricPrompt with @kit.UserAuthenticationKit. The concept is similar (hardware-backed key that requires user authentication to use).

4. **QR Scanning**: Replace CameraX + ZXing with HarmonyOS @kit.ScanKit for QR code scanning.

5. **File Storage**: Replace Android's `Context.getFilesDir()` + AtomicFile with HarmonyOS application sandbox file APIs.

6. **SharedPreferences**: Replace with HarmonyOS @ohos.data.preferences or AppStorage.

7. **Room Database**: Replace with HarmonyOS @ohos.data.relationalStore for audit log.

8. **Glide**: Replace with HarmonyOS Image component with custom decoders for SVG support.

9. **No Network**: The app is fully offline - no network calls to convert.

10. **Entry Storage**: NOT a database - it's a JSON file with UUIDMap in-memory. This simplifies HarmonyOS conversion significantly.
