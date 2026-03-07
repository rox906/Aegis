import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { VaultService } from '../service/VaultService';

@Entry
@Component
struct ExportPage {
  @State exportFormat: string = 'json';
  @State isExporting: boolean = false;
  @State lastExportPath: string = '';

  private getContext(): common.Context | undefined {
    try {
      return getContext(this) as common.Context;
    } catch (err) {
      return undefined;
    }
  }

  private exportVault(): void {
    const vault = VaultService.getInstance();
    if (!vault.isVaultLoaded()) {
      promptAction.showToast({ message: 'Vault is not loaded' });
      return;
    }

    this.isExporting = true;

    try {
      const json = vault.exportVault();
      const ctx = this.getContext();
      if (ctx === undefined) {
        promptAction.showToast({ message: 'Cannot access file system' });
        this.isExporting = false;
        return;
      }

      const timestamp = new Date().getTime();
      const fileName = `aegis-export-${timestamp}.json`;
      const filePath = `${ctx.cacheDir}/${fileName}`;

      const file = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(json);
      fileIo.writeSync(file.fd, data.buffer);
      fileIo.closeSync(file);

      this.lastExportPath = filePath;
      this.isExporting = false;
      promptAction.showToast({ message: `Exported to ${fileName}` });
    } catch (err) {
      this.isExporting = false;
      const msg = (err instanceof Error) ? err.message : 'Export failed';
      promptAction.showToast({ message: msg });
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24)
          .onClick(() => { router.back(); })

        Text('Export Vault')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()

      Column() {
        Text('Export your vault entries to a file.')
          .fontSize(16)
          .margin({ top: 24 })

        Text('The exported file will be in Aegis JSON format (unencrypted).')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 })

        Text('Warning: The exported file will contain your secrets in plain text. Keep it safe!')
          .fontSize(14)
          .fontColor('#E65100')
          .margin({ top: 16 })
          .padding(12)
          .backgroundColor('#FFF3E0')
          .borderRadius(8)

        Button(this.isExporting ? 'Exporting...' : 'Export to JSON')
          .width('80%')
          .height(48)
          .margin({ top: 32 })
          .enabled(!this.isExporting)
          .onClick(() => { this.exportVault(); })

        if (this.lastExportPath.length > 0) {
          Text(`Last export: ${this.lastExportPath}`)
            .fontSize(12)
            .fontColor('#888888')
            .margin({ top: 16 })
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
