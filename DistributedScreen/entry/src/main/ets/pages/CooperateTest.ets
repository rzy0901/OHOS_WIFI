/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import cooperateManager from '../model/CooperateManager';
import { CooperateStatus, CooperateStatusInfo, MouseLocation, MouseLocationEventData } from '../model/CooperateTypes';
import Logger from '../common/Logger';
import constant from '../common/Constant';
import deviceManager from '@ohos.distributedDeviceManager';
import { RemoteDeviceModel } from '../model/RemoteDeviceModel';
import router from '@ohos.router';

const TAG: string = '[CooperateTest]';

/**
 * 键鼠穿越测试页面
 * 专门用于测试键鼠穿越功能的简洁页面
 */
@Entry
@Component
struct CooperateTest {
  @State currentStatus: CooperateStatus = CooperateStatus.IDLE;
  @State selectedDevice: deviceManager.DeviceBasicInfo | null = null;
  @State availableDevices: deviceManager.DeviceBasicInfo[] = [];
  @State mousePosition: string = '无鼠标位置信息';
  @State isInitialized: boolean = false;
  @State isStarting: boolean = false;
  @State isStopping: boolean = false;
  
  private remoteDeviceModel: RemoteDeviceModel = RemoteDeviceModel.getInstance();

  async aboutToAppear() {
    await this.initializeCooperateManager();
    await this.loadAvailableDevices();
  }

  aboutToDisappear() {
    this.cleanupCooperateManager();
  }

  /**
   * 初始化键鼠穿越管理器
   */
  private async initializeCooperateManager(): Promise<void> {
    try {
      Logger.info(TAG, 'Initializing cooperate manager...');
      
      await cooperateManager.initialize();
      this.isInitialized = true;
      
      // 设置事件监听器
      this.setupEventListeners();
      
      // 更新初始状态
      this.updateStatus();
      
      constant.showToast('键鼠穿越功能初始化成功');
      Logger.info(TAG, 'Cooperate manager initialized successfully');
      
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize cooperate manager: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('键鼠穿越功能初始化失败: ' + errorMessage);
    }
  }

  /**
   * 清理键鼠穿越管理器
   */
  private cleanupCooperateManager(): void {
    try {
      Logger.info(TAG, 'Cleaning up cooperate manager...');
      
      // 移除事件监听器
      cooperateManager.offStatusChanged(this.onStatusChanged);
      cooperateManager.offMouseLocationChanged(this.onMouseLocationChanged);
      cooperateManager.offError(this.onError);
      
      // 销毁管理器
      cooperateManager.destroy();
      this.isInitialized = false;
      
      Logger.info(TAG, 'Cooperate manager cleaned up');
    } catch (error) {
      Logger.error(TAG, 'Error cleaning up cooperate manager: ' + JSON.stringify(error));
    }
  }

  /**
   * 加载可用设备
   */
  private async loadAvailableDevices(): Promise<void> {
    try {
      await this.remoteDeviceModel.createDeviceManager();
      this.availableDevices = this.remoteDeviceModel.trustedDeviceList;
      Logger.info(TAG, 'Loaded available devices: ' + this.availableDevices.length);
    } catch (error) {
      Logger.error(TAG, 'Failed to load devices: ' + JSON.stringify(error));
      constant.showToast('加载设备列表失败');
    }
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    // 监听状态变化
    cooperateManager.onStatusChanged(this.onStatusChanged);
    
    // 监听鼠标位置变化
    cooperateManager.onMouseLocationChanged(this.onMouseLocationChanged);
    
    // 监听错误事件
    cooperateManager.onError(this.onError);
  }

  /**
   * 状态变化回调
   */
  private onStatusChanged = (statusInfo: CooperateStatusInfo): void => {
    Logger.info(TAG, 'Status changed: ' + JSON.stringify(statusInfo));
    this.currentStatus = statusInfo.status;
  }

  /**
   * 鼠标位置变化回调
   */
  private onMouseLocationChanged = (data: MouseLocationEventData): void => {
    const networkId = data.networkId;
    const location = data.location;
    this.mousePosition = `设备: ${networkId}\nX: ${location.displayX}, Y: ${location.displayY}\n屏幕: ${location.displayWidth}x${location.displayHeight}`;
  }

  /**
   * 错误事件回调
   */
  private onError = (error: Error): void => {
    Logger.error(TAG, 'Cooperate error: ' + error.message);
    constant.showToast('键鼠穿越错误: ' + error.message);
  }

  /**
   * 更新状态
   */
  private updateStatus(): void {
    this.currentStatus = cooperateManager.getStatus();
  }

  /**
   * 开始键鼠穿越
   */
  private async startCooperate(): Promise<void> {
    if (!this.selectedDevice) {
      constant.showToast('请先选择目标设备');
      return;
    }

    try {
      this.isStarting = true;
      const deviceNetworkId = this.selectedDevice.networkId;
      if (!deviceNetworkId) {
        throw new Error('设备网络ID不可用');
      }
      
      Logger.info(TAG, 'Starting cooperate to device: ' + deviceNetworkId);
      await cooperateManager.startCooperate(deviceNetworkId, 0);
      
      // 开始追踪鼠标位置
      cooperateManager.startTrackingMouseLocation(deviceNetworkId);
      
      constant.showToast('键鼠穿越启动成功');
    } catch (error) {
      Logger.error(TAG, 'Failed to start cooperate: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('键鼠穿越启动失败: ' + errorMessage);
    } finally {
      this.isStarting = false;
    }
  }

  /**
   * 停止键鼠穿越
   */
  private async stopCooperate(): Promise<void> {
    try {
      this.isStopping = true;
      Logger.info(TAG, 'Stopping cooperate...');
      
      // 停止追踪鼠标位置
      if (this.selectedDevice && this.selectedDevice.networkId) {
        const deviceNetworkId = this.selectedDevice.networkId;
        cooperateManager.stopTrackingMouseLocation(deviceNetworkId);
      }
      
      await cooperateManager.stopCooperate(false);
      
      this.mousePosition = '无鼠标位置信息';
      constant.showToast('键鼠穿越已停止');
    } catch (error) {
      Logger.error(TAG, 'Failed to stop cooperate: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('键鼠穿越停止失败: ' + errorMessage);
    } finally {
      this.isStopping = false;
    }
  }

  /**
   * 检查设备支持状态
   */
  private async checkDeviceSupport(): Promise<void> {
    if (!this.selectedDevice) {
      constant.showToast('请先选择设备');
      return;
    }

    try {
      const deviceNetworkId = this.selectedDevice.networkId;
      if (!deviceNetworkId) {
        throw new Error('设备网络ID不可用');
      }
      const isSupported = await cooperateManager.isDeviceSupported(deviceNetworkId);
      const message = isSupported ? '设备支持键鼠穿越' : '设备不支持键鼠穿越';
      constant.showToast(message);
    } catch (error) {
      Logger.error(TAG, 'Failed to check device support: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('检查设备支持状态失败: ' + errorMessage);
    }
  }

  /**
   * 返回主页
   */
  private goBack(): void {
    router.back();
  }

  /**
   * 获取状态颜色
   */
  private getStatusColor(): Color {
    switch (this.currentStatus) {
      case CooperateStatus.ACTIVE:
        return Color.Green;
      case CooperateStatus.ERROR:
        return Color.Red;
      case CooperateStatus.PREPARING:
      case CooperateStatus.ACTIVATING:
      case CooperateStatus.DEACTIVATING:
        return Color.Orange;
      default:
        return Color.Gray;
    }
  }

  /**
   * 获取状态文本
   */
  private getStatusText(): string {
    switch (this.currentStatus) {
      case CooperateStatus.IDLE:
        return '空闲';
      case CooperateStatus.PREPARING:
        return '准备中...';
      case CooperateStatus.PREPARED:
        return '已准备';
      case CooperateStatus.ACTIVATING:
        return '启动中...';
      case CooperateStatus.ACTIVE:
        return '已激活';
      case CooperateStatus.DEACTIVATING:
        return '停止中...';
      case CooperateStatus.ERROR:
        return '错误';
      default:
        return '未知状态';
    }
  }

  build() {
    Column({ space: 20 }) {
      // 标题栏
      Row() {
        Button('← 返回')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor(Color.Blue)
          .onClick(() => this.goBack())
        
        Blank()
        
        Text('键鼠穿越测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 状态显示区域
      Column({ space: 15 }) {
        Text('当前状态')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Row() {
          Text('初始化: ')
            .fontSize(16)
          Text(this.isInitialized ? '已初始化' : '未初始化')
            .fontSize(16)
            .fontColor(this.isInitialized ? Color.Green : Color.Red)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Row() {
          Text('状态: ')
            .fontSize(16)
          Text(this.getStatusText())
            .fontSize(16)
            .fontColor(this.getStatusColor())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1F000000' })

      // 设备选择区域
      Column({ space: 15 }) {
        Text('设备选择')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        if (this.selectedDevice) {
          Text(`已选择: ${this.selectedDevice.deviceName}`)
            .fontSize(14)
            .fontColor(Color.Blue)
        } else {
          Text('未选择设备')
            .fontSize(14)
            .fontColor(Color.Gray)
        }

        // 设备列表
        if (this.availableDevices.length > 0) {
          ForEach(this.availableDevices, (device: deviceManager.DeviceBasicInfo, index: number) => {
            Button(device.deviceName)
              .width('100%')
              .backgroundColor(this.selectedDevice?.deviceId === device.deviceId ? Color.Blue : Color.Gray)
              .fontColor(Color.White)
              .onClick(() => {
                this.selectedDevice = device;
                constant.showToast('已选择设备: ' + device.deviceName);
              })
          })
        } else {
          Text('没有可用设备')
            .fontSize(14)
            .fontColor(Color.Gray)
        }

        Button('刷新设备列表')
          .backgroundColor(Color.Orange)
          .fontColor(Color.White)
          .onClick(() => this.loadAvailableDevices())
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1F000000' })

      // 控制按钮区域
      Column({ space: 15 }) {
        Text('控制操作')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 20 }) {
          Button(this.isStarting ? '启动中...' : '开始穿越')
            .enabled(this.isInitialized && 
                    this.selectedDevice != null && 
                    this.currentStatus === CooperateStatus.IDLE &&
                    !this.isStarting)
            .backgroundColor(Color.Green)
            .fontColor(Color.White)
            .layoutWeight(1)
            .onClick(() => this.startCooperate())

          Button(this.isStopping ? '停止中...' : '停止穿越')
            .enabled(this.isInitialized && 
                    this.currentStatus === CooperateStatus.ACTIVE &&
                    !this.isStopping)
            .backgroundColor(Color.Red)
            .fontColor(Color.White)
            .layoutWeight(1)
            .onClick(() => this.stopCooperate())
        }

        Button('检查设备支持')
          .enabled(this.isInitialized && this.selectedDevice != null)
          .backgroundColor(Color.Blue)
          .fontColor(Color.White)
          .width('100%')
          .onClick(() => this.checkDeviceSupport())
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1F000000' })

      // 鼠标位置信息
      Column({ space: 10 }) {
        Text('鼠标位置信息')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Text(this.mousePosition)
          .fontSize(12)
          .fontColor(Color.Gray)
          .textAlign(TextAlign.Start)
          .width('100%')
          .padding(10)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1F000000' })

      Flex().layoutWeight(1)
    }
    .height('100%')
    .width('100%')
    .padding(16)
    .backgroundColor('#F0F0F0')
  }
}
