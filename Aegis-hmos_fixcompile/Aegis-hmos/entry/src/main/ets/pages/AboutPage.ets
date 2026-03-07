import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24)
          .onClick(() => { router.back(); })

        Text('About')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()

      Scroll() {
        Column() {
          // App icon
          Image($r('app.media.layered_image'))
            .width(96).height(96)
            .margin({ top: 40 })

          Text('Aegis Authenticator')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 16 })

          Text('v1.0.0')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 4 })

          Text('A free, secure and open source app for managing your two-step verification tokens.')
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .margin({ top: 16, left: 32, right: 32 })

          Divider().margin({ top: 32, bottom: 16 })

          // Info items
          this.infoItem('Developer', 'Beem Development')
          this.infoItem('License', 'GPL-3.0')
          this.infoItem('Platform', 'HarmonyOS NEXT')

          Divider().margin({ top: 16, bottom: 16 })

          Text('Based on the open-source Aegis Authenticator for Android')
            .fontSize(12)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
            .margin({ left: 32, right: 32 })

          Blank().height(40)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  infoItem(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .layoutWeight(1)
      Text(value)
        .fontSize(16)
        .fontColor('#666666')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}
