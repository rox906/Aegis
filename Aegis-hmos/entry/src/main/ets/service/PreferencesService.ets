import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class PreferencesService {
  private static instance: PreferencesService | undefined = undefined;

  static getInstance(): PreferencesService {
    if (PreferencesService.instance === undefined) {
      PreferencesService.instance = new PreferencesService();
    }
    return PreferencesService.instance;
  }

  private store: preferences.Preferences | undefined = undefined;

  async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'aegis_prefs');
  }

  private ensureInitialized(): preferences.Preferences {
    if (this.store === undefined) {
      throw new Error('PreferencesService not initialized');
    }
    return this.store;
  }

  // ---- pref_intro (boolean, default false) ----

  async getIntroDone(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_intro', false)) as boolean;
  }

  async setIntroDone(done: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_intro', done);
    await store.flush();
  }

  // ---- pref_tap_to_reveal (boolean, default false) ----

  async getTapToReveal(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_tap_to_reveal', false)) as boolean;
  }

  async setTapToReveal(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_tap_to_reveal', enabled);
    await store.flush();
  }

  // ---- pref_tap_to_reveal_time (number, default 30) ----

  async getTapToRevealTime(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_tap_to_reveal_time', 30)) as number;
  }

  async setTapToRevealTime(seconds: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_tap_to_reveal_time', seconds);
    await store.flush();
  }

  // ---- pref_highlight_entry (boolean, default false) ----

  async getHighlightEntry(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_highlight_entry', false)) as boolean;
  }

  async setHighlightEntry(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_highlight_entry', enabled);
    await store.flush();
  }

  // ---- pref_haptic_feedback (boolean, default true) ----

  async getHapticFeedback(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_haptic_feedback', true)) as boolean;
  }

  async setHapticFeedback(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_haptic_feedback', enabled);
    await store.flush();
  }

  // ---- pref_pause_entry (boolean, default false) ----

  async getPauseEntry(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_pause_entry', false)) as boolean;
  }

  async setPauseEntry(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_pause_entry', enabled);
    await store.flush();
  }

  // ---- pref_secure_screen (boolean, default true) ----

  async getSecureScreen(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_secure_screen', true)) as boolean;
  }

  async setSecureScreen(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_secure_screen', enabled);
    await store.flush();
  }

  // ---- pref_panic_trigger (boolean, default false) ----

  async getPanicTrigger(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_panic_trigger', false)) as boolean;
  }

  async setPanicTrigger(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_panic_trigger', enabled);
    await store.flush();
  }

  // ---- pref_current_sort_category (number, default 0) ----

  async getCurrentSortCategory(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_current_sort_category', 0)) as number;
  }

  async setCurrentSortCategory(ordinal: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_current_sort_category', ordinal);
    await store.flush();
  }

  // ---- pref_current_view_mode (number, default 0) ----

  async getCurrentViewMode(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_current_view_mode', 0)) as number;
  }

  async setCurrentViewMode(ordinal: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_current_view_mode', ordinal);
    await store.flush();
  }

  // ---- pref_current_theme (number, default 0) ----

  async getCurrentTheme(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_current_theme', 0)) as number;
  }

  async setCurrentTheme(ordinal: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_current_theme', ordinal);
    await store.flush();
  }

  // ---- pref_current_copy_behavior (number, default 0) ----

  async getCurrentCopyBehavior(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_current_copy_behavior', 0)) as number;
  }

  async setCurrentCopyBehavior(ordinal: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_current_copy_behavior', ordinal);
    await store.flush();
  }

  // ---- pref_account_name_position (number, default 0) ----

  async getAccountNamePosition(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_account_name_position', 0)) as number;
  }

  async setAccountNamePosition(ordinal: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_account_name_position', ordinal);
    await store.flush();
  }

  // ---- pref_code_group_size_string (string, default "GROUPING_THREES") ----

  async getCodeGroupSize(): Promise<string> {
    const store = this.ensureInitialized();
    return (await store.get('pref_code_group_size_string', 'GROUPING_THREES')) as string;
  }

  async setCodeGroupSize(grouping: string): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_code_group_size_string', grouping);
    await store.flush();
  }

  // ---- pref_auto_lock_mask (number, default 10) ----

  async getAutoLockMask(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_auto_lock_mask', 10)) as number;
  }

  async setAutoLockMask(mask: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_auto_lock_mask', mask);
    await store.flush();
  }

  // ---- pref_search_behavior_mask (number, default 3) ----

  async getSearchBehaviorMask(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_search_behavior_mask', 3)) as number;
  }

  async setSearchBehaviorMask(mask: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_search_behavior_mask', mask);
    await store.flush();
  }

  // ---- pref_show_icons (boolean, default true) ----

  async getShowIcons(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_show_icons', true)) as boolean;
  }

  async setShowIcons(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_show_icons', enabled);
    await store.flush();
  }

  // ---- pref_show_next_code (boolean, default false) ----

  async getShowNextCode(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_show_next_code', false)) as boolean;
  }

  async setShowNextCode(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_show_next_code', enabled);
    await store.flush();
  }

  // ---- pref_expiration_state (boolean, default true) ----

  async getExpirationState(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_expiration_state', true)) as boolean;
  }

  async setExpirationState(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_expiration_state', enabled);
    await store.flush();
  }

  // ---- pref_password_reminder_freq (number, default 2 = BIWEEKLY) ----

  async getPasswordReminderFreq(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_password_reminder_freq', 2)) as number;
  }

  async setPasswordReminderFreq(freq: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_password_reminder_freq', freq);
    await store.flush();
  }

  // ---- pref_password_reminder_counter (number, default Date.now()) ----

  async getPasswordReminderCounter(): Promise<number> {
    const store = this.ensureInitialized();
    const value = await store.get('pref_password_reminder_counter', -1);
    const result = value as number;
    if (result === -1) {
      return Date.now();
    }
    return result;
  }

  async setPasswordReminderCounter(timestamp: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_password_reminder_counter', timestamp);
    await store.flush();
  }

  // ---- pref_backups (boolean, default false) ----

  async getBackupsEnabled(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_backups', false)) as boolean;
  }

  async setBackupsEnabled(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_backups', enabled);
    await store.flush();
  }

  // ---- pref_backup_reminder (boolean, default true) ----

  async getBackupReminder(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_backup_reminder', true)) as boolean;
  }

  async setBackupReminder(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_backup_reminder', enabled);
    await store.flush();
  }

  // ---- pref_pin_keyboard (boolean, default false) ----

  async getPinKeyboard(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_pin_keyboard', false)) as boolean;
  }

  async setPinKeyboard(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_pin_keyboard', enabled);
    await store.flush();
  }

  // ---- pref_focus_search (boolean, default false) ----

  async getFocusSearch(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_focus_search', false)) as boolean;
  }

  async setFocusSearch(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_focus_search', enabled);
    await store.flush();
  }

  // ---- pref_minimize_on_copy (boolean, default false) ----

  async getMinimizeOnCopy(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_minimize_on_copy', false)) as boolean;
  }

  async setMinimizeOnCopy(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_minimize_on_copy', enabled);
    await store.flush();
  }

  // ---- pref_groups_multiselect (boolean, default false) ----

  async getGroupsMultiselect(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_groups_multiselect', false)) as boolean;
  }

  async setGroupsMultiselect(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_groups_multiselect', enabled);
    await store.flush();
  }

  // ---- pref_dynamic_colors (boolean, default false) ----

  async getDynamicColors(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_dynamic_colors', false)) as boolean;
  }

  async setDynamicColors(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_dynamic_colors', enabled);
    await store.flush();
  }

  // ---- pref_warn_time_sync (boolean, default true) ----

  async getWarnTimeSync(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_warn_time_sync', true)) as boolean;
  }

  async setWarnTimeSync(enabled: boolean): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_warn_time_sync', enabled);
    await store.flush();
  }

  // ---- pref_lang (string, default "system") ----

  async getLanguage(): Promise<string> {
    const store = this.ensureInitialized();
    return (await store.get('pref_lang', 'system')) as string;
  }

  async setLanguage(lang: string): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_lang', lang);
    await store.flush();
  }

  // ---- pref_timeout (number, default -1) ----

  async getLockTimeout(): Promise<number> {
    const store = this.ensureInitialized();
    return (await store.get('pref_timeout', -1)) as number;
  }

  async setLockTimeout(seconds: number): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_timeout', seconds);
    await store.flush();
  }

  // ---- pref_group_filter_uuids (string, default "") ----

  async getGroupFilterUuids(): Promise<string> {
    const store = this.ensureInitialized();
    return (await store.get('pref_group_filter_uuids', '')) as string;
  }

  async setGroupFilterUuids(jsonArray: string): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_group_filter_uuids', jsonArray);
    await store.flush();
  }

  // ---- pref_usage_count (string, default "") ----

  async getUsageCount(): Promise<string> {
    const store = this.ensureInitialized();
    return (await store.get('pref_usage_count', '')) as string;
  }

  async setUsageCount(jsonArray: string): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_usage_count', jsonArray);
    await store.flush();
  }

  // ---- pref_last_used_timestamps (string, default "") ----

  async getLastUsedTimestamps(): Promise<string> {
    const store = this.ensureInitialized();
    return (await store.get('pref_last_used_timestamps', '')) as string;
  }

  async setLastUsedTimestamps(jsonArray: string): Promise<void> {
    const store = this.ensureInitialized();
    await store.put('pref_last_used_timestamps', jsonArray);
    await store.flush();
  }
}

