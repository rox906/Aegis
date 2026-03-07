import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';
import { PreferencesService } from '../service/PreferencesService';
import { DatabaseService } from '../service/DatabaseService';

const DOMAIN = 0x0000;
const TAG = 'AegisAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    try {
      // 1. Initialize VaultService (file-based, needs context for filesDir)
      VaultService.getInstance().init(this.context);
      hilog.info(DOMAIN, TAG, 'VaultService initialized');

      // 2. Initialize PreferencesService
      await PreferencesService.getInstance().init(this.context);
      hilog.info(DOMAIN, TAG, 'PreferencesService initialized');

      // 3. Initialize DatabaseService (audit log)
      await DatabaseService.getInstance().init(this.context);
      hilog.info(DOMAIN, TAG, 'DatabaseService initialized');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Service initialization failed: %{public}s',
        (err instanceof Error) ? err.message : String(err));
    }

    // Load the main page
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}