/*
 * Copyright (c) 2023 AlgoIdeas <yu19881234@163.com>
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Ability from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import Logger from '../common/Logger';
import userGrantPermission from '../utils/Permission';
import remoteDeviceModel from '../model/RemoteDeviceModel';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { GlobalContext, getGlobalObject, setGlobalObject } from '../common/GlobalThis'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';
import { common } from '@kit.AbilityKit';

const TAG: string = "[EntryAbility]"
const permissions: Array<Permissions> = ['ohos.permission.DISTRIBUTED_DATASYNC', 'ohos.permission.ACCESS_DISTRIBUTED_HARDWARE', 'ohos.permission.COOPERATE_MANAGER', 'ohos.permission.INPUT_MONITORING'];

function reqPermissionsFromUser(permissions: Array<Permissions>, context: common.UIAbilityContext): void {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
  atManager.requestPermissionsFromUser(context, permissions).then((data) => {
    let grantStatus: Array<number> = data.authResults;
    let length: number = grantStatus.length;
    for (let i = 0; i < length; i++) {
      if (grantStatus[i] === 0) {
        // 用户授权，可以继续访问目标操作
      } else {
        // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限
        return;
      }
    }
    // 授权成功
  }).catch((err: BusinessError) => {
    Logger.error(TAG, `Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
  })
}

export default class EntryAbility extends Ability {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    setGlobalObject('this.context', this.context);
    setGlobalObject('this.context.resourceManager', this.context.resourceManager);
    this.initFilterOption();
    remoteDeviceModel.createDeviceManager();
    Logger.info(TAG, 'Ability onCreate');
  }

  getStringByResource(r: Resource) {
    return this.context.resourceManager.getStringSync(r.id);
  }

  initFilterOption() {
    let DeviceTypeItemList: Array<string> = [
    this.context.resourceManager.getStringSync($r('app.string.no_filter')),
    this.context.resourceManager.getStringSync($r('app.string.tablet')),
    this.context.resourceManager.getStringSync($r('app.string.phone')),
    this.context.resourceManager.getStringSync($r('app.string.other')),
    ];
    setGlobalObject('DeviceTypeItemList', DeviceTypeItemList);
    let AuthFormItemList: Array<string> = [
    this.context.resourceManager.getStringSync($r('app.string.no_filter')),
    this.context.resourceManager.getStringSync($r('app.string.identical_account')),
    this.context.resourceManager.getStringSync($r('app.string.across_account')),
    this.context.resourceManager.getStringSync($r('app.string.no_account')),
    ];
    setGlobalObject('AuthFormItemList', AuthFormItemList);

    let IsOnlineItemList: Array<string> = [
    this.context.resourceManager.getStringSync($r('app.string.no_filter')),
    this.context.resourceManager.getStringSync($r('app.string.online')),
    this.context.resourceManager.getStringSync($r('app.string.offline')),
    ];
    setGlobalObject('IsOnlineItemList', IsOnlineItemList);

    let IsTrustedItemList: Array<string> = [
    this.context.resourceManager.getStringSync($r('app.string.no_filter')),
    this.context.resourceManager.getStringSync($r('app.string.credible')),
    this.context.resourceManager.getStringSync($r('app.string.incredible')),
    ];
    setGlobalObject('IsTrustedItemList', IsTrustedItemList);

    let RangeItemList: Array<string> = [
    this.context.resourceManager.getStringSync($r('app.string.no_filter')), '50', '80', '100'];
    setGlobalObject('RangeItemList', RangeItemList);
  }

  onDestroy() {
    Logger.info(TAG, 'Ability onDestroy');
    remoteDeviceModel.unregisterDeviceListCallback();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // Main window is created, set main page for this ability
    Logger.info(TAG, 'Ability onWindowStageCreate');

    reqPermissionsFromUser(permissions, this.context);

    let loadContentUrl = 'pages/Index';
    windowStage.loadContent(loadContentUrl, (err, data) => {
      if (err.code) {
        Logger.error(TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }

      userGrantPermission(this.context, {
        permissions: [
          {
              "name": "ohos.permission.INTERNET"
          },
          {
            "name": "ohos.permission.CAPTURE_SCREEN"
          },
          {
              "name": "ohos.permission.DISTRIBUTED_DATASYNC"
          },
          {
            "name": "ohos.permission.GET_BUNDLE_INFO"
          },
          {
            "name": "ohos.permission.ACCESS_SERVICE_DM"
          },
          {
            "name": "ohos.permission.ACCESS_DISTRIBUTED_HARDWARE"
          }
        ]
      })

      Logger.info(TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  onWindowStageDestroy() {
    // Main window is destroyed, release UI related resources
    Logger.info(TAG, 'Ability onWindowStageDestroy');
  }

  onForeground() {
    // Ability has brought to foreground
    Logger.info(TAG, 'Ability onForeground');
  }

  onBackground() {
    // Ability has back to background
    Logger.info(TAG, 'Ability onBackground');
  }
}
