import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';
import { PreferencesService } from '../service/PreferencesService';

@Entry
@Component
struct IntroPage {
  build() {
    Column() {
      Blank().layoutWeight(1)

      Image($r('app.media.layered_image'))
        .width(120)
        .height(120)

      Text('Aegis Authenticator')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24 })

      Text('A free, secure and open source app for managing your 2-step verification tokens.')
        .fontSize(16)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
        .margin({ top: 12, left: 32, right: 32 })

      Blank().layoutWeight(1)

      Button('Get Started')
        .width('80%')
        .height(48)
        .onClick(() => {
          VaultService.getInstance().initNewVault();
          PreferencesService.getInstance().setIntroDone(true).catch(() => {});
          router.replaceUrl({ url: 'pages/Index' });
        })
        .margin({ bottom: 16 })

      Button('Import Existing Vault')
        .width('80%')
        .height(48)
        .backgroundColor(Color.Transparent)
        .fontColor('#1976D2')
        .onClick(() => {
          promptAction.showToast({ message: 'Import coming soon' });
        })
        .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
