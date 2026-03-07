import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { VaultService } from '../service/VaultService';
import { VaultGroup } from '../model/VaultModels';
import { generateUUID } from '../util/Encoding';

@Entry
@Component
struct GroupManagerPage {
  @State groups: VaultGroup[] = [];
  @State newGroupName: string = '';
  @State editingGroupUuid: string = '';
  @State editingGroupName: string = '';

  aboutToAppear(): void {
    this.loadGroups();
  }

  private loadGroups(): void {
    this.groups = VaultService.getInstance().getGroups().slice();
  }

  private addGroup(): void {
    const name = this.newGroupName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: 'Group name cannot be empty' });
      return;
    }

    const group: VaultGroup = {
      uuid: generateUUID(),
      name: name
    };

    VaultService.getInstance().addGroup(group);
    VaultService.getInstance().saveVault();
    this.newGroupName = '';
    this.loadGroups();
    promptAction.showToast({ message: 'Group added' });
  }

  private deleteGroup(uuid: string): void {
    AlertDialog.show({
      title: 'Delete Group',
      message: 'Are you sure you want to delete this group? Entries in this group will not be deleted.',
      primaryButton: {
        value: 'Cancel',
        action: () => {}
      },
      secondaryButton: {
        value: 'Delete',
        fontColor: Color.Red,
        action: () => {
          VaultService.getInstance().removeGroup(uuid);
          VaultService.getInstance().saveVault();
          this.loadGroups();
          promptAction.showToast({ message: 'Group deleted' });
        }
      }
    });
  }

  private renameGroup(uuid: string, newName: string): void {
    if (newName.trim().length === 0) {
      promptAction.showToast({ message: 'Group name cannot be empty' });
      return;
    }
    VaultService.getInstance().renameGroup(uuid, newName.trim());
    VaultService.getInstance().saveVault();
    this.editingGroupUuid = '';
    this.editingGroupName = '';
    this.loadGroups();
    promptAction.showToast({ message: 'Group renamed' });
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24)
          .onClick(() => { router.back(); })

        Text('Manage Groups')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()

      // Add group input
      Row() {
        TextInput({ text: this.newGroupName, placeholder: 'New group name' })
          .layoutWeight(1)
          .onChange((value: string) => { this.newGroupName = value; })
          .onSubmit(() => { this.addGroup(); })

        Button('Add')
          .margin({ left: 8 })
          .onClick(() => { this.addGroup(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()

      // Group list
      if (this.groups.length === 0) {
        Column() {
          Text('No groups yet')
            .fontSize(16)
            .fontColor('#888888')
            .margin({ top: 60 })
          Text('Create a group to organize your entries')
            .fontSize(14)
            .fontColor('#AAAAAA')
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.groups, (group: VaultGroup) => {
            ListItem() {
              if (this.editingGroupUuid === group.uuid) {
                Row() {
                  TextInput({ text: this.editingGroupName })
                    .layoutWeight(1)
                    .onChange((value: string) => { this.editingGroupName = value; })
                    .onSubmit(() => { this.renameGroup(group.uuid, this.editingGroupName); })

                  Button('Save')
                    .fontSize(14)
                    .margin({ left: 8 })
                    .onClick(() => { this.renameGroup(group.uuid, this.editingGroupName); })

                  Button('Cancel')
                    .fontSize(14)
                    .backgroundColor('#E0E0E0')
                    .fontColor('#333333')
                    .margin({ left: 4 })
                    .onClick(() => {
                      this.editingGroupUuid = '';
                      this.editingGroupName = '';
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
              } else {
                Row() {
                  Text(group.name)
                    .fontSize(16)
                    .layoutWeight(1)

                  Image($r('sys.media.ohos_ic_public_edit'))
                    .width(24).height(24)
                    .margin({ right: 16 })
                    .onClick(() => {
                      this.editingGroupUuid = group.uuid;
                      this.editingGroupName = group.name;
                    })

                  Image($r('sys.media.ohos_ic_public_remove'))
                    .width(24).height(24)
                    .fillColor(Color.Red)
                    .onClick(() => { this.deleteGroup(group.uuid); })
                }
                .width('100%')
                .height(56)
                .padding({ left: 16, right: 16 })
                .alignItems(VerticalAlign.Center)
              }
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#E0E0E0', startMargin: 16, endMargin: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
