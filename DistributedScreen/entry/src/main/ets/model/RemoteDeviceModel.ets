/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
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

import constant from '../common/Constant';
import deviceManager from '@ohos.distributedDeviceManager';
import Logger from '../common/Logger';
import { BusinessError } from '@ohos.base';
import { getGlobalObject } from '../common/GlobalThis'

const TAG: string = '[RemoteDeviceModel]'

class FilterOptions {
  availableStatus: number = 0;
  discoverDistance: number = 0;
  authenticationStatus: number = 0;
  authorizationType: number = 0;
}

class Data {
  device: deviceManager.DeviceBasicInfo = {
    deviceId: '',
    deviceName: '',
    deviceType: '',
    networkId: ''
  };
}

class dataType {
  action: deviceManager.DeviceStateChange = 0;
  device: deviceManager.DeviceBasicInfo = {
    deviceId: '',
    deviceName: '',
    deviceType: '',
    networkId: ''
  };
}

export class RemoteDeviceModel {
  private static dmInstance: RemoteDeviceModel = new RemoteDeviceModel();
  trustedDeviceList: Array<deviceManager.DeviceBasicInfo> = [];
  discoverList: Array<deviceManager.DeviceBasicInfo> = [];
  localDevice: deviceManager.DeviceBasicInfo = {
    deviceId: "",
    deviceName: "",
    deviceType: "",
    networkId: ""
  };
  deviceManager?: deviceManager.DeviceManager;
  isSupportRange: boolean = false;
  private discoverParam: Record<string, number> = {
    'discoverTargetType': 1
  };
  private filterOptions: Record<string, number> = {
    'availableStatus': 0
  };
  private bindParamObj: Record<string, string | number> = {
    'bindType': 1,
    'targetPkgName': 'ohos.samples.distributedscreen',
    'appName': '分布式屏幕',
    'appOperation': '想要连接本机。',
    'customDescription': '用于进行数据同步及设备间协同操作'
  }

  static getInstance(): RemoteDeviceModel {
    if (RemoteDeviceModel.dmInstance === undefined) {
      RemoteDeviceModel.dmInstance = new RemoteDeviceModel();
    }
    return RemoteDeviceModel.dmInstance!;
  }

  constructor() {
  }

  async createDeviceManager(): Promise<void> {
    if (typeof (this.deviceManager) != 'undefined') {
      return;
    }

    Logger.info(TAG, 'deviceManager.createDeviceManager begin');
    let self = this;
    await new Promise((resolve: (value: deviceManager.DeviceManager) => void, reject: (reason: Error) => void) => {
      try {
        let dmInstance = deviceManager.createDeviceManager('ohos.samples.distributedscreen');
        self.deviceManager = dmInstance;
        self.getLocalDeviceInfo();
        self.registerDeviceStateListener();
        self.getTrustedDeviceList();
        Logger.info(TAG, 'createDeviceManager callback success');
        resolve(dmInstance);
      } catch (err) {
        let e: BusinessError = err as BusinessError;
        reject(err);
        Logger.error(TAG, 'createDeviceManager errCode:' + e.code + ',errMessage:' + e.message);
      }
    })
    Logger.info(TAG, 'deviceManager.createDeviceManager end');
  }

  getLocalDeviceInfo(): void {
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      return;
    }

    Logger.info(TAG, 'getLocalDeviceInfo begin');
    this.localDevice.deviceId = this.deviceManager.getLocalDeviceId();
    this.localDevice.deviceName = this.deviceManager.getLocalDeviceName();
    this.localDevice.deviceType = this.deviceManager.getLocalDeviceType().toString();
    this.localDevice.networkId = this.deviceManager.getLocalDeviceNetworkId();
    AppStorage.SetOrCreate('localDevice', this.localDevice);
    Logger.info(TAG, 'getLocalDeviceInfo end localDevice = ' + JSON.stringify(this.localDevice));
  }

  getTrustedDeviceList(): void {
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }

    Logger.info(TAG, 'getTrustedDeviceList begin');
    try {
      this.trustedDeviceList = this.deviceManager.getAvailableDeviceListSync();
      AppStorage.SetOrCreate('trustedDeviceList', this.trustedDeviceList);
    } catch (error) {
      Logger.error(TAG, 'getTrustedDeviceList error: ${error}' + error.toString());
      constant.showToast('getTrustedDeviceList failed');
    }
  }

  setIsSupportRange(value: boolean): void {
    this.isSupportRange = value;
  }

  deviceStateChangeActionOnline(device: deviceManager.DeviceBasicInfo): void {
    this.trustedDeviceList[this.trustedDeviceList.length] = device;
    Logger.info(TAG, 'online, device list = ' + JSON.stringify(this.trustedDeviceList));
    for (let i = this.discoverList.length - 1; i >= 0; i--) {
      if (this.discoverList[i].deviceId == device.deviceId) {
        this.discoverList.splice(i, 1);
        break;
      }
    }
    for (let j = 0; j < this.trustedDeviceList.length; j++) {
      if (this.trustedDeviceList[j].deviceId === device.deviceId) {
        this.trustedDeviceList[j] = device;
        break;
      }
    }
    AppStorage.SetOrCreate('discoverDeviceList', this.discoverList);
    AppStorage.SetOrCreate('trustedDeviceList', this.trustedDeviceList);
  }

  deviceStateChangeActionOffline(device: deviceManager.DeviceBasicInfo): void {
    Logger.info(TAG, 'offline, this.trustedDeviceList.length=' +
    this.trustedDeviceList.length);
    let list: Array<deviceManager.DeviceBasicInfo> = [];
    for (let i = 0; i < this.trustedDeviceList.length; i++) {
      if (this.trustedDeviceList[i].deviceId !== device.deviceId) {
        list.push(this.trustedDeviceList[i]);
      }
    }
    this.trustedDeviceList = list;
    AppStorage.SetOrCreate('trustedDeviceList', this.trustedDeviceList);
    Logger.info(TAG, 'offline, device list=' + JSON.stringify(this.trustedDeviceList));
  }

  registerDeviceStateListener(): void {
    Logger.info(TAG, 'registerDeviceStateListener');
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }

    let self = this;
    this.deviceManager.on('deviceStateChange', (data: dataType) => {
      if (data == null) {
        return;
      }
      Logger.info(TAG, 'deviceStateChange data=' + JSON.stringify(data));
      switch (data.action) {
        case deviceManager.DeviceStateChange.UNKNOWN:
          Logger.info(TAG, 'deviceStateChange UNKNOWN');
          self.deviceStateChangeActionOnline(data.device!);
          break;
        case deviceManager.DeviceStateChange.AVAILABLE:
          Logger.info(TAG, 'deviceStateChange AVAILABLE');
          break;
        case deviceManager.DeviceStateChange.UNAVAILABLE:
          Logger.info(TAG, 'deviceStateChange UNAVAILABLE');
          self.deviceStateChangeActionOffline(data.device!);
          break;
        default:
          break;
      }
    })
  }

  deviceFound(data: Data): void {
    for (let i = 0; i < this.discoverList.length; i++) {
      if (this.discoverList[i].deviceId == data.device!.deviceId) {
        Logger.info(TAG, 'device founded ignored');
        return;
      }
    }
    this.discoverList[this.discoverList.length] = data.device!;
    AppStorage.SetOrCreate('discoverDeviceList', this.discoverList);
    Logger.info(TAG, 'deviceFound self.discoverList=' + this.discoverList);
  }

  private getFilterOptions(): Object {
    let filterOptions = new FilterOptions();
    Logger.info('currentFilterOptions' + JSON.stringify(getGlobalObject('filterOptions')));
    let currentFilterOptions = getGlobalObject('filterOptions') as Map<string, number>;
    let deviceTypeName = getGlobalObject("deviceTypeName") as string;
    let authFormName = getGlobalObject("authFormName") as string;
    let isOnlineName = getGlobalObject("isOnlineName") as string;
    let isTrustedName = getGlobalObject("isTrustedName") as string;
    let rangeName = getGlobalObject("rangeName") as string;
    let deviceType = currentFilterOptions.get(deviceTypeName)
    let authForm = currentFilterOptions.get(authFormName)
    let isOnline = currentFilterOptions.get(isOnlineName)
    let isTrusted = currentFilterOptions.get(isTrustedName)
    let range = currentFilterOptions.get(rangeName)
    if (isOnline !== 0) {
      filterOptions.availableStatus = isOnline == 1 ? 1 : 0;
    }

    if (isTrusted != 0) {
      filterOptions.authenticationStatus = isTrusted == 1 ? 1 : 0;
    }

    if (authForm != 0) {
      let authForm = -1;
      if (authForm == 0) {
        authForm = 0;
      }
      if (authForm == 1) {
        authForm = 1;
      }
      if (authForm == 2) {
        authForm = 2;
      }
      filterOptions.authorizationType = authForm;
    }

    if (range != 0) {
      let range = 0;
      if (range == 1) {
        range = 50;
      }
      if (range == 2) {
        range = 80;
      }
      if (range == 3) {
        range = 100;
      }
      filterOptions.discoverDistance = range;
    }
    return filterOptions;
  }

  startDeviceDiscovery(): void {
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }
    let self = this;
    this.deviceManager.on('discoverSuccess', (data: Data) => {
      Logger.info(TAG, 'discoverSuccess data=' + JSON.stringify(data));

      if (data == null) {
        return;
      }
      self.deviceFound(data);
    })
    this.deviceManager.on('discoverFailure', (data) => {
      Logger.info(TAG, 'discoverFailure data=' + JSON.stringify(data));
    })
    this.deviceManager.on('serviceDie', () => {
      Logger.error(TAG, 'serviceDie');
    })

    this.discoverList = [];
    AppStorage.SetOrCreate('discoverDeviceList', this.discoverList);

    let filterOptions = this.getFilterOptions();
    Logger.info(TAG, 'startDeviceDiscovery filterOptions = ' + JSON.stringify(filterOptions));
    try {
      if (filterOptions == '') {
        Logger.info(TAG, 'startDeviceDiscovery');
        this.deviceManager.startDiscovering(this.discoverParam);
      } else {
        this.deviceManager.startDiscovering(this.discoverParam, this.filterOptions);
      }
    } catch (e) {
      Logger.error(TAG, 'startDeviceDiscovery failed err: ' + e.toString());
    }
  }

  stopDeviceDiscovery(): void {
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }
    try {
      this.deviceManager.stopDiscovering();
      this.deviceManager.off('discoverSuccess');
      this.deviceManager.off('discoverFailure');
    } catch (e) {
      Logger.error(TAG, 'stopDiscovering failed err: ' + e.toString());
    }
  }

  unregisterDeviceListCallback(): void {
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }
    try {
      this.stopDeviceDiscovery();
      this.deviceManager.off('deviceStateChange');
      this.deviceManager.off('serviceDie');
      this.trustedDeviceList = [];
      this.discoverList = [];
    } catch (e) {
      Logger.error(TAG, 'stopDeviceDiscovery failed err: ' + e.toString());
    }
  }


  authenticateDevice(device: deviceManager.DeviceBasicInfo): void {
    Logger.info(TAG, 'authenticateDevice ' + JSON.stringify(device));
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }

    for (let i = 0; i < this.discoverList.length; i++) {
      if (this.discoverList[i].deviceId != device.deviceId) {
        continue;
      }
      let bindParam = this.bindParamObj;
      try {
        this.deviceManager.bindTarget(device.deviceId, bindParam, (err: BusinessError, data: Object) => {
          if (err) {
            Logger.info(TAG, 'bindTarget error:' + JSON.stringify(err));
            return;
          }
          Logger.info(TAG, 'bindTarget succeed:' + JSON.stringify(data));
        })
      } catch (e) {
        Logger.error(TAG, 'bindTarget failed err: ' + e.toString());
      }
    }
  }

  unAuthenticateDevice(device: deviceManager.DeviceBasicInfo): void {
    Logger.info(TAG, 'unAuthenticateDevice ' + JSON.stringify(device));
    if (typeof (this.deviceManager) == 'undefined') {
      Logger.error(TAG, 'deviceManager has not initialized');
      constant.showToast('deviceManager has not initialized');
      return;
    }

    for (let i = 0; i < this.trustedDeviceList.length; i++) {
      if (this.trustedDeviceList[i].deviceId != device.deviceId) {
        continue;
      }
      try {
        this.deviceManager.unbindTarget(device.deviceId)
      } catch (e) {
        Logger.error(TAG, 'unbindTarget failed err: ' + e.toString());
      }
    }
  }
}

export default RemoteDeviceModel.getInstance();