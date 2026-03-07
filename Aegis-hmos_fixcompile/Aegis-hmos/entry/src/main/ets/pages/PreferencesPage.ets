import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import {
  SortCategory,
  ViewMode,
  CopyBehavior,
  AccountNamePosition,
  CodeGrouping,
  AppTheme
} from '../model/VaultModels';

@Entry
@Component
struct PreferencesPage {
  @State tapToReveal: boolean = false;
  @State entryHighlight: boolean = false;
  @State showIcons: boolean = true;
  @State showNextCode: boolean = false;
  @State showExpiration: boolean = true;
  @State hapticFeedback: boolean = true;
  @State minimizeOnCopy: boolean = false;
  @State focusSearch: boolean = false;
  @State secureScreen: boolean = true;
  @State pinKeyboard: boolean = false;
  @State timeSyncWarning: boolean = true;

  @State currentTheme: number = 0;
  @State currentViewMode: number = 0;
  @State copyBehavior: number = 0;
  @State codeGrouping: string = 'GROUPING_THREES';

  private themeNames: string[] = ['System', 'Light', 'Dark', 'AMOLED', 'System AMOLED'];
  private viewModeNames: string[] = ['Normal', 'Compact', 'Small', 'Tiles'];
  private copyBehaviorNames: string[] = ['Never', 'Single Tap', 'Double Tap'];
  private codeGroupingNames: string[] = ['Halves', 'No Grouping', 'Twos', 'Threes', 'Fours'];

  aboutToAppear(): void {
    // Load preferences from PreferencesService when available
    // For now use defaults
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24)
          .onClick(() => { router.back(); })

        Text('Settings')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()

      // Settings list
      List() {
        // Appearance section
        ListItem() {
          this.sectionHeader('Appearance')
        }

        ListItem() {
          this.settingSelect('Theme', this.themeNames[this.currentTheme], () => {
            this.showSelectDialog('Theme', this.themeNames, this.currentTheme, (index: number) => {
              this.currentTheme = index;
            });
          })
        }

        ListItem() {
          this.settingSelect('View Mode', this.viewModeNames[this.currentViewMode], () => {
            this.showSelectDialog('View Mode', this.viewModeNames, this.currentViewMode, (index: number) => {
              this.currentViewMode = index;
            });
          })
        }

        ListItem() {
          this.settingToggle('Show Icons', this.showIcons, (v: boolean) => { this.showIcons = v; })
        }

        ListItem() {
          this.settingToggle('Show Next Code', this.showNextCode, (v: boolean) => { this.showNextCode = v; })
        }

        ListItem() {
          this.settingToggle('Show Expiration State', this.showExpiration, (v: boolean) => { this.showExpiration = v; })
        }

        // Behavior section
        ListItem() {
          this.sectionHeader('Behavior')
        }

        ListItem() {
          this.settingSelect('Copy Behavior', this.copyBehaviorNames[this.copyBehavior], () => {
            this.showSelectDialog('Copy Behavior', this.copyBehaviorNames, this.copyBehavior, (index: number) => {
              this.copyBehavior = index;
            });
          })
        }

        ListItem() {
          this.settingToggle('Tap to Reveal', this.tapToReveal, (v: boolean) => { this.tapToReveal = v; })
        }

        ListItem() {
          this.settingToggle('Highlight Entry', this.entryHighlight, (v: boolean) => { this.entryHighlight = v; })
        }

        ListItem() {
          this.settingToggle('Haptic Feedback', this.hapticFeedback, (v: boolean) => { this.hapticFeedback = v; })
        }

        ListItem() {
          this.settingToggle('Minimize on Copy', this.minimizeOnCopy, (v: boolean) => { this.minimizeOnCopy = v; })
        }

        ListItem() {
          this.settingToggle('Focus Search on Start', this.focusSearch, (v: boolean) => { this.focusSearch = v; })
        }

        // Security section
        ListItem() {
          this.sectionHeader('Security')
        }

        ListItem() {
          this.settingToggle('Secure Screen', this.secureScreen, (v: boolean) => { this.secureScreen = v; })
        }

        ListItem() {
          this.settingToggle('PIN Keyboard', this.pinKeyboard, (v: boolean) => { this.pinKeyboard = v; })
        }

        ListItem() {
          this.settingToggle('Time Sync Warning', this.timeSyncWarning, (v: boolean) => { this.timeSyncWarning = v; })
        }

        // Backups section
        ListItem() {
          this.sectionHeader('Backups')
        }

        ListItem() {
          this.settingAction('Export Vault', () => {
            router.pushUrl({ url: 'pages/ExportPage' });
          })
        }

        // Groups section
        ListItem() {
          this.sectionHeader('Groups')
        }

        ListItem() {
          this.settingAction('Manage Groups', () => {
            router.pushUrl({ url: 'pages/GroupManagerPage' });
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#E0E0E0', startMargin: 16, endMargin: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1976D2')
      .padding({ left: 16, top: 16, bottom: 8 })
      .width('100%')
  }

  @Builder
  settingToggle(title: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => { onChange(isOn); })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  settingSelect(title: string, currentValue: string, onTap: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(16)
        Text(currentValue).fontSize(14).fontColor('#888888').margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { onTap(); })
  }

  @Builder
  settingAction(title: string, onTap: () => void) {
    Row() {
      Text(title).fontSize(16).layoutWeight(1)
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(20).height(20)
        .fillColor('#888888')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { onTap(); })
  }

  private showSelectDialog(title: string, options: string[], currentIndex: number, onSelect: (index: number) => void): void {
    AlertDialog.show({
      title: title,
      message: options.join('\n'),
      primaryButton: {
        value: 'Cancel',
        action: () => {}
      },
      secondaryButton: {
        value: 'OK',
        action: () => {}
      }
    });
    // Simple selection - in a real app would use ActionSheet
    // For now cycle through options
    const nextIndex = (currentIndex + 1) % options.length;
    onSelect(nextIndex);
  }
}
