import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';

@Entry
@Component
struct AuthPage {
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    const vault: VaultService = VaultService.getInstance();
    if (!vault.isEncrypted()) {
      // Unencrypted vault - load directly and navigate to main page
      try {
        vault.loadVault();
        router.replaceUrl({ url: 'pages/Index' });
      } catch (err) {
        this.errorMessage = 'Failed to load vault';
      }
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)

      Image($r('app.media.layered_image'))
        .width(80)
        .height(80)

      Text('Vault Locked')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16 })

      TextInput({ placeholder: 'Enter password', text: this.password })
        .type(InputType.Password)
        .width('80%')
        .margin({ top: 32 })
        .onChange((value: string) => {
          this.password = value;
        })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontColor(Color.Red)
          .fontSize(14)
          .margin({ top: 8 })
      }

      Button('Unlock')
        .width('80%')
        .height(48)
        .margin({ top: 16 })
        .enabled(!this.isLoading)
        .onClick(() => {
          // Encrypted vault decryption not yet supported
          promptAction.showToast({ message: 'Encrypted vault support coming soon' });
        })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
