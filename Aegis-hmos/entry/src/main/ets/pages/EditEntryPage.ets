import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';
import {
  VaultEntry,
  VaultGroup
} from '../model/VaultModels';
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
import { Base32 } from '../util/Encoding';
import { generateUUID } from '../util/Encoding';

interface EditEntryParams {
  uuid?: string;
  entryUuid?: string;
}

@Entry
@Component
struct EditEntryPage {
  @State isEditMode: boolean = false;
  @State entryUuid: string = '';

  // Form fields
  @State issuer: string = '';
  @State accountName: string = '';
  @State secret: string = '';
  @State otpType: string = 'totp';
  @State algorithm: string = 'SHA1';
  @State digits: number = 6;
  @State period: number = 30;
  @State counter: number = 0;
  @State pin: string = '';
  @State note: string = '';
  @State isFavorite: boolean = false;

  @State selectedGroups: Set<string> = new Set<string>();
  @State availableGroups: VaultGroup[] = [];

  @State showAdvanced: boolean = false;

  private otpTypes: string[] = ['totp', 'hotp', 'steam', 'motp', 'yandex'];
  private algorithms: string[] = ['SHA1', 'SHA256', 'SHA512', 'MD5'];
  private digitOptions: number[] = [5, 6, 7, 8];

  aboutToAppear(): void {
    const params = router.getParams() as EditEntryParams | undefined;
    const uid = params !== undefined ? (params.entryUuid || params.uuid) : undefined;
    if (uid !== undefined) {
      this.isEditMode = true;
      this.entryUuid = uid;
      this.loadEntry(uid);
    }
    this.availableGroups = VaultService.getInstance().getGroups();
  }

  private loadEntry(uuid: string): void {
    const entry = VaultService.getInstance().getEntryByUUID(uuid);
    if (entry === undefined) {
      promptAction.showToast({ message: 'Entry not found' });
      router.back();
      return;
    }

    this.issuer = entry.issuer;
    this.accountName = entry.name;
    this.secret = Base32.encode(entry.info.secret);
    this.note = entry.note;
    this.isFavorite = entry.isFavorite;
    this.selectedGroups = new Set<string>(entry.groups);

    this.otpType = entry.info.type as string;
    this.algorithm = entry.info.algorithm as string;
    this.digits = entry.info.digits;

    if (entry.info.type === OtpType.TOTP || entry.info.type === OtpType.STEAM) {
      this.period = (entry.info as TotpInfo).period;
    } else if (entry.info.type === OtpType.HOTP) {
      this.counter = (entry.info as HotpInfo).counter;
    } else if (entry.info.type === OtpType.MOTP) {
      this.period = (entry.info as MotpInfo).period;
      this.pin = (entry.info as MotpInfo).pin;
    } else if (entry.info.type === OtpType.YANDEX) {
      this.period = (entry.info as YandexInfo).period;
      this.pin = (entry.info as YandexInfo).pin;
    }
  }

  private buildOtpInfo(): AnyOtpInfo {
    let secretBytes: Uint8Array;
    try {
      secretBytes = Base32.decode(this.secret);
    } catch (err) {
      throw new Error('Invalid secret: must be valid Base32');
    }

    if (secretBytes.length === 0) {
      throw new Error('Secret cannot be empty');
    }

    const algo = this.algorithm as OtpAlgorithm;

    switch (this.otpType) {
      case 'totp': {
        const info: TotpInfo = {
          type: OtpType.TOTP,
          secret: secretBytes,
          algorithm: algo,
          digits: this.digits,
          period: this.period
        };
        return info;
      }
      case 'steam': {
        const info: SteamInfo = {
          type: OtpType.STEAM,
          secret: secretBytes,
          algorithm: algo,
          digits: this.digits,
          period: this.period
        };
        return info;
      }
      case 'hotp': {
        const info: HotpInfo = {
          type: OtpType.HOTP,
          secret: secretBytes,
          algorithm: algo,
          digits: this.digits,
          counter: this.counter
        };
        return info;
      }
      case 'motp': {
        const info: MotpInfo = {
          type: OtpType.MOTP,
          secret: secretBytes,
          algorithm: OtpAlgorithm.MD5,
          digits: this.digits,
          period: this.period,
          pin: this.pin
        };
        return info;
      }
      case 'yandex': {
        const info: YandexInfo = {
          type: OtpType.YANDEX,
          secret: secretBytes,
          algorithm: OtpAlgorithm.SHA256,
          digits: 8,
          period: 30,
          pin: this.pin
        };
        return info;
      }
      default:
        throw new Error(`Unsupported OTP type: ${this.otpType}`);
    }
  }

  private saveEntry(): void {
    if (this.secret.trim().length === 0) {
      promptAction.showToast({ message: 'Secret is required' });
      return;
    }

    let otpInfo: AnyOtpInfo;
    try {
      otpInfo = this.buildOtpInfo();
    } catch (err) {
      const msg = (err instanceof Error) ? err.message : 'Invalid OTP configuration';
      promptAction.showToast({ message: msg });
      return;
    }

    const vault = VaultService.getInstance();

    if (this.isEditMode) {
      const existing = vault.getEntryByUUID(this.entryUuid);
      if (existing !== undefined) {
        const updated: VaultEntry = {
          uuid: this.entryUuid,
          name: this.accountName,
          issuer: this.issuer,
          info: otpInfo,
          icon: existing.icon,
          isFavorite: this.isFavorite,
          usageCount: existing.usageCount,
          lastUsedTimestamp: existing.lastUsedTimestamp,
          note: this.note,
          groups: this.selectedGroups
        };
        vault.updateEntry(updated);
      }
    } else {
      const newEntry: VaultEntry = {
        uuid: generateUUID(),
        name: this.accountName,
        issuer: this.issuer,
        info: otpInfo,
        icon: undefined,
        isFavorite: this.isFavorite,
        usageCount: 0,
        lastUsedTimestamp: 0,
        note: this.note,
        groups: this.selectedGroups
      };
      vault.addEntry(newEntry);
    }

    vault.saveVault();
    promptAction.showToast({ message: this.isEditMode ? 'Entry updated' : 'Entry added' });
    router.back();
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24)
          .onClick(() => { router.back(); })

        Text(this.isEditMode ? 'Edit Entry' : 'Add Entry')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
          .layoutWeight(1)

        Button('Save')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor('#1976D2')
          .onClick(() => { this.saveEntry(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      // Form content
      Scroll() {
        Column() {
          // Issuer
          Text('Issuer').fontSize(14).fontColor('#666666').margin({ top: 16 })
          TextInput({ text: this.issuer, placeholder: 'e.g. Google' })
            .width('100%')
            .margin({ top: 4 })
            .onChange((value: string) => { this.issuer = value; })

          // Account Name
          Text('Account Name').fontSize(14).fontColor('#666666').margin({ top: 16 })
          TextInput({ text: this.accountName, placeholder: 'e.g. john@example.com' })
            .width('100%')
            .margin({ top: 4 })
            .onChange((value: string) => { this.accountName = value; })

          // Secret
          Text('Secret (Base32)').fontSize(14).fontColor('#666666').margin({ top: 16 })
          TextInput({ text: this.secret, placeholder: 'JBSWY3DPEHPK3PXP' })
            .width('100%')
            .margin({ top: 4 })
            .type(InputType.Normal)
            .onChange((value: string) => { this.secret = value; })

          // OTP Type selector
          Text('Type').fontSize(14).fontColor('#666666').margin({ top: 16 })
          Row() {
            ForEach(this.otpTypes, (type: string) => {
              Button(type.toUpperCase())
                .fontSize(12)
                .height(36)
                .backgroundColor(this.otpType === type ? '#1976D2' : '#E0E0E0')
                .fontColor(this.otpType === type ? Color.White : '#333333')
                .borderRadius(18)
                .margin({ right: 8 })
                .onClick(() => {
                  this.otpType = type;
                  if (type === 'steam') {
                    this.digits = STEAM_DEFAULT_DIGITS;
                  } else if (type === 'yandex') {
                    this.digits = 8;
                    this.algorithm = 'SHA256';
                  } else if (type === 'motp') {
                    this.algorithm = 'MD5';
                  } else {
                    this.digits = OTP_DEFAULT_DIGITS;
                  }
                })
            })
          }
          .width('100%')
          .margin({ top: 4 })

          // Advanced toggle
          Row() {
            Text('Advanced Settings')
              .fontSize(14)
              .fontColor('#1976D2')
            Image(this.showAdvanced ? $r('sys.media.ohos_ic_public_arrow_up') : $r('sys.media.ohos_ic_public_arrow_down'))
              .width(16).height(16)
              .margin({ left: 8 })
          }
          .margin({ top: 20 })
          .onClick(() => { this.showAdvanced = !this.showAdvanced; })

          if (this.showAdvanced) {
            // Algorithm
            if (this.otpType !== 'motp' && this.otpType !== 'yandex') {
              Text('Algorithm').fontSize(14).fontColor('#666666').margin({ top: 12 })
              Row() {
                ForEach(this.algorithms, (algo: string) => {
                  Button(algo)
                    .fontSize(12)
                    .height(32)
                    .backgroundColor(this.algorithm === algo ? '#1976D2' : '#E0E0E0')
                    .fontColor(this.algorithm === algo ? Color.White : '#333333')
                    .borderRadius(16)
                    .margin({ right: 8 })
                    .onClick(() => { this.algorithm = algo; })
                })
              }
              .margin({ top: 4 })
            }

            // Digits
            Text('Digits').fontSize(14).fontColor('#666666').margin({ top: 12 })
            Row() {
              ForEach(this.digitOptions, (d: number) => {
                Button(d.toString())
                  .fontSize(12)
                  .width(48).height(32)
                  .backgroundColor(this.digits === d ? '#1976D2' : '#E0E0E0')
                  .fontColor(this.digits === d ? Color.White : '#333333')
                  .borderRadius(16)
                  .margin({ right: 8 })
                  .onClick(() => { this.digits = d; })
              })
            }
            .margin({ top: 4 })

            // Period (for TOTP, Steam, mOTP)
            if (this.otpType === 'totp' || this.otpType === 'steam' || this.otpType === 'motp') {
              Text('Period (seconds)').fontSize(14).fontColor('#666666').margin({ top: 12 })
              TextInput({ text: this.period.toString() })
                .type(InputType.Number)
                .width('100%')
                .margin({ top: 4 })
                .onChange((value: string) => {
                  const n = parseInt(value);
                  if (!isNaN(n) && n > 0) {
                    this.period = n;
                  }
                })
            }

            // Counter (for HOTP)
            if (this.otpType === 'hotp') {
              Text('Counter').fontSize(14).fontColor('#666666').margin({ top: 12 })
              TextInput({ text: this.counter.toString() })
                .type(InputType.Number)
                .width('100%')
                .margin({ top: 4 })
                .onChange((value: string) => {
                  const n = parseInt(value);
                  if (!isNaN(n) && n >= 0) {
                    this.counter = n;
                  }
                })
            }

            // PIN (for mOTP, Yandex)
            if (this.otpType === 'motp' || this.otpType === 'yandex') {
              Text('PIN').fontSize(14).fontColor('#666666').margin({ top: 12 })
              TextInput({ text: this.pin, placeholder: 'Enter PIN' })
                .type(InputType.Password)
                .width('100%')
                .margin({ top: 4 })
                .onChange((value: string) => { this.pin = value; })
            }
          }

          // Note
          Text('Note').fontSize(14).fontColor('#666666').margin({ top: 16 })
          TextArea({ text: this.note, placeholder: 'Optional note' })
            .width('100%')
            .height(80)
            .margin({ top: 4 })
            .onChange((value: string) => { this.note = value; })

          // Favorite toggle
          Row() {
            Toggle({ type: ToggleType.Switch, isOn: this.isFavorite })
              .onChange((isOn: boolean) => { this.isFavorite = isOn; })
            Text('Favorite')
              .fontSize(16)
              .margin({ left: 12 })
          }
          .width('100%')
          .margin({ top: 16 })
          .alignItems(VerticalAlign.Center)

          // Group assignment
          if (this.availableGroups.length > 0) {
            Text('Groups').fontSize(14).fontColor('#666666').margin({ top: 16 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.availableGroups, (group: VaultGroup) => {
                Button(group.name)
                  .fontSize(12)
                  .height(32)
                  .backgroundColor(this.selectedGroups.has(group.uuid) ? '#1976D2' : '#E0E0E0')
                  .fontColor(this.selectedGroups.has(group.uuid) ? Color.White : '#333333')
                  .borderRadius(16)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    const newGroups = new Set<string>(this.selectedGroups);
                    if (newGroups.has(group.uuid)) {
                      newGroups.delete(group.uuid);
                    } else {
                      newGroups.add(group.uuid);
                    }
                    this.selectedGroups = newGroups;
                  })
              })
            }
            .margin({ top: 4 })
          }

          // Bottom spacer
          Blank().height(40)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
