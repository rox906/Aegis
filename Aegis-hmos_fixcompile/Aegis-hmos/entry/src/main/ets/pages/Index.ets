import { router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';
import { OtpService } from '../service/OtpService';
import { PreferencesService } from '../service/PreferencesService';
import { VaultEntry, VaultGroup, SortCategory, CopyBehavior } from '../model/VaultModels';
import { OtpType, HotpInfo, TotpInfo, SteamInfo, MotpInfo, YandexInfo, getOtpPeriod, isTimeBased } from '../model/OtpModels';

interface EntryDisplayItem {
  entry: VaultEntry;
  otpCode: string;
  nextCode: string;
  progress: number;
}

@Entry
@Component
struct Index {
  @State entries: EntryDisplayItem[] = [];
  @State searchQuery: string = '';
  @State selectedGroupUuid: string = '';
  @State sortCategory: SortCategory = SortCategory.CUSTOM;
  @State groups: VaultGroup[] = [];
  @State isSearchVisible: boolean = false;
  @State isMenuVisible: boolean = false;
  @State isSortMenuVisible: boolean = false;
  @State isLoading: boolean = true;
  @State copyBehavior: number = 0;
  @State tapToReveal: boolean = false;
  @State tapToRevealTime: number = 30;
  @State showIcons: boolean = true;
  @State codeGroupSize: number = 3;
  @State revealedEntryUuid: string = '';

  private vaultService: VaultService = VaultService.getInstance();
  private prefsService: PreferencesService = PreferencesService.getInstance();
  private timerId: number = -1;
  private revealTimerId: number = -1;

  aboutToAppear(): void {
    if (this.vaultService.isVaultInitNeeded()) {
      router.replaceUrl({ url: 'pages/IntroPage' });
      return;
    }

    if (this.vaultService.isEncrypted() && this.vaultService.isVaultLocked()) {
      router.replaceUrl({ url: 'pages/AuthPage' });
      return;
    }

    if (!this.vaultService.isVaultLoaded()) {
      try {
        this.vaultService.loadVault();
      } catch (err) {
        promptAction.showToast({ message: 'Failed to load vault' });
        return;
      }
    }

    if (this.vaultService.isVaultLocked()) {
      router.replaceUrl({ url: 'pages/AuthPage' });
      return;
    }

    this.groups = this.vaultService.getGroups();
    this.loadPreferences();
    this.loadAndRefreshCodes();

    this.timerId = setInterval(() => {
      this.refreshCodes();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.revealTimerId !== -1) {
      clearTimeout(this.revealTimerId);
      this.revealTimerId = -1;
    }
  }

  private loadPreferences(): void {
    this.prefsService.getCurrentCopyBehavior().then((val: number) => { this.copyBehavior = val; }).catch(() => {});
    this.prefsService.getTapToReveal().then((val: boolean) => { this.tapToReveal = val; }).catch(() => {});
    this.prefsService.getTapToRevealTime().then((val: number) => { this.tapToRevealTime = val; }).catch(() => {});
    this.prefsService.getShowIcons().then((val: boolean) => { this.showIcons = val; }).catch(() => {});
    this.prefsService.getCodeGroupSize().then((val: string) => {
      switch (val) {
        case 'HALVES': this.codeGroupSize = -1; break;
        case 'NO_GROUPING': this.codeGroupSize = -2; break;
        case 'GROUPING_TWOS': this.codeGroupSize = 2; break;
        case 'GROUPING_THREES': this.codeGroupSize = 3; break;
        case 'GROUPING_FOURS': this.codeGroupSize = 4; break;
        default: this.codeGroupSize = 3; break;
      }
    }).catch(() => {});
    this.prefsService.getCurrentSortCategory().then((val: number) => {
      this.sortCategory = val as SortCategory;
    }).catch(() => {});
  }

  onPageShow(): void {
    if (this.vaultService.isVaultLoaded() && !this.vaultService.isVaultLocked()) {
      this.groups = this.vaultService.getGroups();
      this.loadAndRefreshCodes();
    }
  }

  private loadAndRefreshCodes(): void {
    this.isLoading = true;
    const vaultEntries = this.vaultService.getEntries();
    const newItems: EntryDisplayItem[] = [];
    for (const entry of vaultEntries) {
      newItems.push({
        entry: entry,
        otpCode: '',
        nextCode: '',
        progress: isTimeBased(entry.info) ? OtpService.getTotpProgress(getOtpPeriod(entry.info)) : 1.0
      });
    }
    this.entries = newItems;
    this.refreshCodes();
    this.isLoading = false;
  }

  private refreshCodes(): void {
    const updated: EntryDisplayItem[] = [];
    for (const item of this.entries) {
      const progress = isTimeBased(item.entry.info)
        ? OtpService.getTotpProgress(getOtpPeriod(item.entry.info))
        : 1.0;
      updated.push({
        entry: item.entry,
        otpCode: item.otpCode,
        nextCode: item.nextCode,
        progress: progress
      });
    }
    this.entries = updated;
    this.generateAllCodes();
  }

  private generateAllCodes(): void {
    for (let i = 0; i < this.entries.length; i++) {
      const idx = i;
      const entry = this.entries[idx].entry;
      OtpService.generateCode(entry.info).then((code: string) => {
        const formatted = OtpService.formatCodeWithGrouping(code, this.codeGroupSize);
        if (idx < this.entries.length && this.entries[idx].entry.uuid === entry.uuid) {
          const updated = [...this.entries];
          updated[idx] = {
            entry: updated[idx].entry,
            otpCode: formatted,
            nextCode: updated[idx].nextCode,
            progress: updated[idx].progress
          };
          this.entries = updated;
        }
      }).catch(() => {
        // Code generation failed - leave blank
      });
    }
  }

  private getFilteredAndSortedEntries(): EntryDisplayItem[] {
    let result: EntryDisplayItem[] = [...this.entries];

    // Group filter
    if (this.selectedGroupUuid !== '') {
      result = result.filter((item: EntryDisplayItem) => {
        return item.entry.groups.has(this.selectedGroupUuid);
      });
    }

    // Search filter
    if (this.searchQuery.length > 0) {
      const query = this.searchQuery.toLowerCase();
      result = result.filter((item: EntryDisplayItem) => {
        const issuerMatch = item.entry.issuer.toLowerCase().includes(query);
        const nameMatch = item.entry.name.toLowerCase().includes(query);
        const noteMatch = item.entry.note.toLowerCase().includes(query);
        return issuerMatch || nameMatch || noteMatch;
      });
    }

    // Sort
    switch (this.sortCategory) {
      case SortCategory.ACCOUNT:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return a.entry.name.toLowerCase().localeCompare(b.entry.name.toLowerCase());
        });
        break;
      case SortCategory.ACCOUNT_REVERSED:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return b.entry.name.toLowerCase().localeCompare(a.entry.name.toLowerCase());
        });
        break;
      case SortCategory.ISSUER:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return a.entry.issuer.toLowerCase().localeCompare(b.entry.issuer.toLowerCase());
        });
        break;
      case SortCategory.ISSUER_REVERSED:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return b.entry.issuer.toLowerCase().localeCompare(a.entry.issuer.toLowerCase());
        });
        break;
      case SortCategory.USAGE_COUNT:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return b.entry.usageCount - a.entry.usageCount;
        });
        break;
      case SortCategory.LAST_USED:
        result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
          return b.entry.lastUsedTimestamp - a.entry.lastUsedTimestamp;
        });
        break;
      case SortCategory.CUSTOM:
      default:
        // Keep original order
        break;
    }

    // Favorites first
    result.sort((a: EntryDisplayItem, b: EntryDisplayItem) => {
      if (a.entry.isFavorite && !b.entry.isFavorite) {
        return -1;
      }
      if (!a.entry.isFavorite && b.entry.isFavorite) {
        return 1;
      }
      return 0;
    });

    return result;
  }

  private copyToClipboard(code: string, issuer: string): void {
    const plainTextData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code.replace(/ /g, ''));
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(plainTextData).then(() => {
      const displayName = issuer.length > 0 ? issuer : 'Code';
      promptAction.showToast({ message: `${displayName} copied` });
    }).catch(() => {
      promptAction.showToast({ message: 'Failed to copy' });
    });
  }

  private lockVault(): void {
    this.vaultService.lock();
    router.replaceUrl({ url: 'pages/AuthPage' });
  }

  private deleteEntry(uuid: string): void {
    try {
      this.vaultService.removeEntry(uuid);
      this.vaultService.saveVault();
      this.loadAndRefreshCodes();
      promptAction.showToast({ message: 'Entry deleted' });
    } catch (err) {
      promptAction.showToast({ message: 'Failed to delete entry' });
    }
  }

  private toggleFavorite(entry: VaultEntry): void {
    const updated: VaultEntry = {
      uuid: entry.uuid,
      name: entry.name,
      issuer: entry.issuer,
      info: entry.info,
      icon: entry.icon,
      isFavorite: !entry.isFavorite,
      usageCount: entry.usageCount,
      lastUsedTimestamp: entry.lastUsedTimestamp,
      note: entry.note,
      groups: entry.groups
    };
    this.vaultService.updateEntry(updated);
    this.vaultService.saveVault();
    this.loadAndRefreshCodes();
    promptAction.showToast({
      message: updated.isFavorite ? 'Added to favorites' : 'Removed from favorites'
    });
  }

  private incrementHotpCounter(entry: VaultEntry): void {
    if (entry.info.type !== OtpType.HOTP) {
      return;
    }
    const hotpInfo = entry.info as HotpInfo;
    const newInfo: HotpInfo = {
      type: OtpType.HOTP,
      secret: hotpInfo.secret,
      algorithm: hotpInfo.algorithm,
      digits: hotpInfo.digits,
      counter: hotpInfo.counter + 1
    };
    const updated: VaultEntry = {
      uuid: entry.uuid,
      name: entry.name,
      issuer: entry.issuer,
      info: newInfo,
      icon: entry.icon,
      isFavorite: entry.isFavorite,
      usageCount: entry.usageCount,
      lastUsedTimestamp: entry.lastUsedTimestamp,
      note: entry.note,
      groups: entry.groups
    };
    this.vaultService.updateEntry(updated);
    this.vaultService.saveVault();
    this.loadAndRefreshCodes();
  }

  private revealCode(entryUuid: string): void {
    this.revealedEntryUuid = entryUuid;
    if (this.revealTimerId !== -1) {
      clearTimeout(this.revealTimerId);
    }
    this.revealTimerId = setTimeout(() => {
      this.revealedEntryUuid = '';
      this.revealTimerId = -1;
    }, this.tapToRevealTime * 1000);
  }

  private isCodeRevealed(entryUuid: string): boolean {
    if (!this.tapToReveal) {
      return true;
    }
    return this.revealedEntryUuid === entryUuid;
  }

  private handleEntryTap(item: EntryDisplayItem): void {
    if (this.tapToReveal && !this.isCodeRevealed(item.entry.uuid)) {
      this.revealCode(item.entry.uuid);
      return;
    }
    // CopyBehavior: 0=NEVER, 1=SINGLETAP, 2=DOUBLETAP
    if (this.copyBehavior === 1) {
      this.incrementUsageCount(item.entry);
      this.copyToClipboard(item.otpCode, item.entry.issuer);
    }
  }

  private incrementUsageCount(entry: VaultEntry): void {
    const updated: VaultEntry = {
      uuid: entry.uuid,
      name: entry.name,
      issuer: entry.issuer,
      info: entry.info,
      icon: entry.icon,
      isFavorite: entry.isFavorite,
      usageCount: entry.usageCount + 1,
      lastUsedTimestamp: Math.floor(Date.now() / 1000),
      note: entry.note,
      groups: entry.groups
    };
    this.vaultService.updateEntry(updated);
    this.vaultService.saveVault();
  }

  private showEntryActionSheet(item: EntryDisplayItem): void {
    const entryName = item.entry.issuer.length > 0 ? item.entry.issuer : item.entry.name;
    const favLabel = item.entry.isFavorite ? 'Remove from Favorites' : 'Add to Favorites';
    ActionSheet.show({
      title: entryName,
      message: 'Choose an action',
      confirm: {
        defaultFocus: false,
        value: 'Cancel',
        action: () => {}
      },
      sheets: [
        {
          title: 'Copy Code',
          action: () => {
            this.incrementUsageCount(item.entry);
            this.copyToClipboard(item.otpCode, item.entry.issuer);
          }
        },
        {
          title: 'Edit',
          action: () => {
            router.pushUrl({
              url: 'pages/EditEntryPage',
              params: { entryUuid: item.entry.uuid }
            });
          }
        },
        {
          title: favLabel,
          action: () => {
            this.toggleFavorite(item.entry);
          }
        },
        {
          title: 'Delete',
          action: () => {
            this.confirmDelete(item);
          }
        }
      ]
    });
  }

  private confirmDelete(item: EntryDisplayItem): void {
    promptAction.showDialog({
      title: 'Delete Entry',
      message: `Are you sure you want to delete "${item.entry.issuer.length > 0 ? item.entry.issuer : item.entry.name}"?`,
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Delete', color: '#FF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteEntry(item.entry.uuid);
      }
    });
  }

  private applySortCategory(category: SortCategory): void {
    this.sortCategory = category;
    this.isSortMenuVisible = false;
  }

  private getSortCategoryLabel(category: SortCategory): string {
    switch (category) {
      case SortCategory.CUSTOM:
        return 'Custom';
      case SortCategory.ACCOUNT:
        return 'Account (A-Z)';
      case SortCategory.ACCOUNT_REVERSED:
        return 'Account (Z-A)';
      case SortCategory.ISSUER:
        return 'Issuer (A-Z)';
      case SortCategory.ISSUER_REVERSED:
        return 'Issuer (Z-A)';
      case SortCategory.USAGE_COUNT:
        return 'Most Used';
      case SortCategory.LAST_USED:
        return 'Recently Used';
      default:
        return 'Custom';
    }
  }

  private getOtpTypeLabel(entry: VaultEntry): string {
    switch (entry.info.type) {
      case OtpType.TOTP:
        return 'TOTP';
      case OtpType.HOTP:
        return 'HOTP';
      case OtpType.STEAM:
        return 'Steam';
      case OtpType.MOTP:
        return 'mOTP';
      case OtpType.YANDEX:
        return 'Yandex';
      default:
        return '';
    }
  }

  private getIssuerInitial(issuer: string): string {
    if (issuer.length > 0) {
      return issuer.charAt(0).toUpperCase();
    }
    return '?';
  }

  @Builder
  ToolbarBuilder() {
    Row() {
      if (this.isSearchVisible) {
        Row() {
          TextInput({ placeholder: 'Search entries...', text: this.searchQuery })
            .layoutWeight(1)
            .height(40)
            .fontSize(16)
            .backgroundColor('#F5F5F5')
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.searchQuery = value;
            })

          Text('X')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#666666')
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.searchQuery = '';
              this.isSearchVisible = false;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 8 })
      } else {
        Text('Aegis')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .padding({ left: 16 })

        // Search button
        Text('\u{1F50D}')
          .fontSize(20)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.isSearchVisible = true;
          })

        // Lock button
        Text('\u{1F512}')
          .fontSize(20)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.lockVault();
          })

        // Sort button
        Text('\u{2195}')
          .fontSize(20)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.showSortMenu();
          })

        // More menu
        Text('\u{22EE}')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.showMoreMenu();
          })
      }
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#1A000000', offsetY: 1 })
  }

  private showSortMenu(): void {
    ActionSheet.show({
      title: 'Sort By',
      message: '',
      confirm: {
        defaultFocus: false,
        value: 'Cancel',
        action: () => {
          // Dismissed
        }
      },
      sheets: [
        {
          title: 'Custom',
          action: () => {
            this.applySortCategory(SortCategory.CUSTOM);
          }
        },
        {
          title: 'Account (A-Z)',
          action: () => {
            this.applySortCategory(SortCategory.ACCOUNT);
          }
        },
        {
          title: 'Account (Z-A)',
          action: () => {
            this.applySortCategory(SortCategory.ACCOUNT_REVERSED);
          }
        },
        {
          title: 'Issuer (A-Z)',
          action: () => {
            this.applySortCategory(SortCategory.ISSUER);
          }
        },
        {
          title: 'Issuer (Z-A)',
          action: () => {
            this.applySortCategory(SortCategory.ISSUER_REVERSED);
          }
        },
        {
          title: 'Most Used',
          action: () => {
            this.applySortCategory(SortCategory.USAGE_COUNT);
          }
        },
        {
          title: 'Recently Used',
          action: () => {
            this.applySortCategory(SortCategory.LAST_USED);
          }
        }
      ]
    });
  }

  private showMoreMenu(): void {
    ActionSheet.show({
      title: 'Menu',
      message: '',
      confirm: {
        defaultFocus: false,
        value: 'Cancel',
        action: () => {
          // Dismissed
        }
      },
      sheets: [
        {
          title: 'Settings',
          action: () => {
            router.pushUrl({ url: 'pages/PreferencesPage' });
          }
        },
        {
          title: 'About',
          action: () => {
            router.pushUrl({ url: 'pages/AboutPage' });
          }
        }
      ]
    });
  }

  @Builder
  GroupChipsBuilder() {
    Scroll() {
      Row({ space: 8 }) {
        // "All" chip
        Text('All')
          .fontSize(14)
          .fontColor(this.selectedGroupUuid === '' ? '#FFFFFF' : '#333333')
          .backgroundColor(this.selectedGroupUuid === '' ? '#5B7CF7' : '#E8E8E8')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .onClick(() => {
            this.selectedGroupUuid = '';
          })

        ForEach(this.groups, (group: VaultGroup) => {
          Text(group.name)
            .fontSize(14)
            .fontColor(this.selectedGroupUuid === group.uuid ? '#FFFFFF' : '#333333')
            .backgroundColor(this.selectedGroupUuid === group.uuid ? '#5B7CF7' : '#E8E8E8')
            .borderRadius(16)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .onClick(() => {
              if (this.selectedGroupUuid === group.uuid) {
                this.selectedGroupUuid = '';
              } else {
                this.selectedGroupUuid = group.uuid;
              }
            })
        }, (group: VaultGroup) => group.uuid)
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  EntryCardBuilder(item: EntryDisplayItem) {
    Row() {
      // Icon circle with initial
      Column() {
        Text(this.getIssuerInitial(item.entry.issuer))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor('#5B7CF7')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      // Entry info
      Column() {
        Row() {
          if (item.entry.isFavorite) {
            Text('\u{2605}')
              .fontSize(14)
              .fontColor('#FFB300')
              .margin({ right: 4 })
          }
          Text(item.entry.issuer.length > 0 ? item.entry.issuer : '(No Issuer)')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.getOtpTypeLabel(item.entry))
            .fontSize(10)
            .fontColor('#888888')
            .borderWidth(1)
            .borderColor('#CCCCCC')
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin({ left: 6 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (item.entry.name.length > 0) {
          Text(item.entry.name)
            .fontSize(13)
            .fontColor('#888888')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }

        Row() {
          if (this.isCodeRevealed(item.entry.uuid)) {
            Text(item.otpCode.length > 0 ? item.otpCode : '------')
              .fontSize(26)
              .fontWeight(FontWeight.Medium)
              .fontColor('#222222')
              .fontFamily('monospace')
              .letterSpacing(2)
              .layoutWeight(1)
          } else {
            Text('\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}')
              .fontSize(26)
              .fontWeight(FontWeight.Medium)
              .fontColor('#AAAAAA')
              .fontFamily('monospace')
              .letterSpacing(2)
              .layoutWeight(1)
          }
        }
        .margin({ top: 4 })
        .width('100%')
      }
      .layoutWeight(1)

      // Right side: progress/refresh + copy
      Column({ space: 8 }) {
        if (isTimeBased(item.entry.info)) {
          Stack() {
            Progress({ value: Math.round(item.progress * 100), total: 100, type: ProgressType.Ring })
              .width(32)
              .height(32)
              .color(item.progress < 0.2 ? '#FF4444' : '#5B7CF7')
              .backgroundColor('#E0E0E0')
              .style({ strokeWidth: 3 })

            Text(`${Math.ceil(item.progress * getOtpPeriod(item.entry.info))}`)
              .fontSize(10)
              .fontColor('#666666')
              .textAlign(TextAlign.Center)
          }
          .width(32)
          .height(32)
        } else if (item.entry.info.type === OtpType.HOTP) {
          // HOTP refresh button
          Text('\u{21BB}')
            .fontSize(22)
            .fontColor('#5B7CF7')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(16)
            .backgroundColor('#EEF1FE')
            .onClick(() => {
              this.incrementHotpCounter(item.entry);
            })
        }

        Text('Copy')
          .fontSize(12)
          .fontColor('#5B7CF7')
          .fontWeight(FontWeight.Medium)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#EEF1FE')
          .onClick(() => {
            this.incrementUsageCount(item.entry);
            this.copyToClipboard(item.otpCode, item.entry.issuer);
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ left: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 4, color: '#0D000000', offsetY: 2 })
    .onClick(() => {
      this.handleEntryTap(item);
    })
    .gesture(LongPressGesture({ repeat: false })
      .onAction(() => {
        this.showEntryActionSheet(item);
      })
    )
  }

  @Builder
  EmptyStateBuilder() {
    Column({ space: 16 }) {
      Text('\u{1F512}')
        .fontSize(64)

      Text('No entries yet')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#666666')

      Text('Tap the + button to add your first OTP entry')
        .fontSize(14)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SearchEmptyBuilder() {
    Column({ space: 12 }) {
      Text('No matching entries')
        .fontSize(16)
        .fontColor('#888888')

      Text(`No entries found for "${this.searchQuery}"`)
        .fontSize(13)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Toolbar
        this.ToolbarBuilder()

        // Group filter chips (only show if groups exist)
        if (this.groups.length > 0) {
          this.GroupChipsBuilder()
        }

        // Sort indicator
        if (this.sortCategory !== SortCategory.CUSTOM) {
          Row() {
            Text(`Sorted by: ${this.getSortCategoryLabel(this.sortCategory)}`)
              .fontSize(12)
              .fontColor('#888888')

            Blank()

            Text('Clear')
              .fontSize(12)
              .fontColor('#5B7CF7')
              .onClick(() => {
                this.sortCategory = SortCategory.CUSTOM;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 4 })
          .backgroundColor('#FAFAFA')
        }

        // Main content
        if (this.entries.length === 0 && !this.isLoading) {
          this.EmptyStateBuilder()
        } else {
          if (this.getFilteredAndSortedEntries().length === 0 && (this.searchQuery.length > 0 || this.selectedGroupUuid !== '')) {
            this.SearchEmptyBuilder()
          } else {
            List({ space: 8 }) {
              ForEach(this.getFilteredAndSortedEntries(), (item: EntryDisplayItem) => {
                ListItem() {
                  this.EntryCardBuilder(item)
                }
              }, (item: EntryDisplayItem) => {
                return `${item.entry.uuid}_${item.otpCode}_${Math.round(item.progress * 100)}`;
              })
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 12, right: 12, top: 8, bottom: 80 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F3F5')

      // FAB
      Button('+')
        .width(56)
        .height(56)
        .fontSize(28)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Normal)
        .backgroundColor('#5B7CF7')
        .borderRadius(28)
        .shadow({ radius: 8, color: '#335B7CF7', offsetY: 4 })
        .margin({ right: 16, bottom: 24 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/EditEntryPage' });
        })
    }
    .width('100%')
    .height('100%')
  }
}
