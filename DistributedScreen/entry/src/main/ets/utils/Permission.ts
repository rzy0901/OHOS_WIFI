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

import logger from "../common/Logger";
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'
import bundleManager from '@ohos.bundle.bundleManager';

interface userGrantPermissionParam {
  permissions: any[],
  bundleName?: string,
  bundleFlag?: number,
  userID?: number,
}

export default async function userGrantPermission(context:any, opts:userGrantPermissionParam, call?:Function) {
  logger.info(`User_Grant start`)
  let {
    permissions = [],
    bundleName = "",
    bundleFlag = bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT, // 数字枚举
    userID = 100, // 系统设置默认100
  } = opts;

  if (!bundleName) {
    bundleName = context.abilityInfo.bundleName
  }

  var tokenID: any = undefined;
  // 获取应用信息
  var appInfo = await bundleManager.getApplicationInfo(bundleName, bundleFlag, userID);

  tokenID = appInfo.accessTokenId;
  var atManager = abilityAccessCtrl.createAtManager();

  let noPermissions: string[] = []
  await Promise.all(permissions.map(async (permission) => {
    // 检验权限是否已授权
    let result = await atManager.checkAccessToken(tokenID, permission.name);
    if (result == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      logger.info(`User_Grant ${permission.name} is authorized`)
    } else {
      noPermissions.push(permission.name)
    }
  }));

  // 申请动态授权
  let res = await context.requestPermissionsFromUser(noPermissions);
  if (res && res.authResults) {
    res.authResults.forEach((r, i) => {
      if (r == 0) {
        logger.info(`User_Grant success! ` + noPermissions[i]);
      } else if (r == -1) {
        logger.error(`User_Grant failed! ` + noPermissions[i]);
      }
    })
  } else {
    logger.error("User_Grant failed!");
  }
  logger.info("User_Grant end")
  if(call){
    call();
  }
}