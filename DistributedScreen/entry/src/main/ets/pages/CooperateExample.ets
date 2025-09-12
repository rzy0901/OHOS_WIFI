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
import { CooperateStatus, CooperateStatusInfo, MouseLocation } from '../model/CooperateTypes';
import Logger from '../common/Logger';
import constant from '../common/Constant';
import deviceManager from '@ohos.distributedDeviceManager';

const TAG: string = '[CooperateExample]';

/**
 * 键鼠穿越功能演示页面
 * 展示如何使用 CooperateManager 实现键鼠穿越功能
 */
@Entry
@Component
struct CooperateExample {
  @State currentStatus: CooperateStatus = CooperateStatus.IDLE;
  @State selectedDevice: deviceManager.DeviceBasicInfo | null = null;
  @State availableDevices: deviceManager.DeviceBasicInfo[] = [];
  @State statusText: string = '未连接';
  @State mousePosition: string = '无鼠标位置信息';
  @State isInitialized: boolean = false;

  aboutToAppear() {
    this.initializeCooperateManager();
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
      
      // 初始化管理器
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
    this.updateStatusText();
  }

  /**
   * 鼠标位置变化回调
   */
  private onMouseLocationChanged = (data: { networkId: string, location: MouseLocation }): void => {
    const { networkId, location } = data;
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
    this.updateStatusText();
  }

  /**
   * 更新状态文本
   */
  private updateStatusText(): void {
    switch (this.currentStatus) {
      case CooperateStatus.IDLE:
        this.statusText = '空闲';
        break;
      case CooperateStatus.PREPARING:
        this.statusText = '准备中...';
        break;
      case CooperateStatus.PREPARED:
        this.statusText = '已准备';
        break;
      case CooperateStatus.ACTIVATING:
        this.statusText = '启动中...';
        break;
      case CooperateStatus.ACTIVE:
        this.statusText = '已激活';
        break;
      case CooperateStatus.DEACTIVATING:
        this.statusText = '停止中...';
        break;
      case CooperateStatus.ERROR:
        this.statusText = '错误';
        break;
      default:
        this.statusText = '未知状态';
        break;
    }
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
    }
  }

  /**
   * 停止键鼠穿越
   */
  private async stopCooperate(): Promise<void> {
    try {
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

  build() {
    Column({ space: 20 }) {
      // 标题
      Text('键鼠穿越演示')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20 })

      // 初始化状态
      Row() {
        Text('初始化状态: ')
          .fontSize(16)
        Text(this.isInitialized ? '已初始化' : '未初始化')
          .fontSize(16)
          .fontColor(this.isInitialized ? Color.Green : Color.Red)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 当前状态
      Row() {
        Text('当前状态: ')
          .fontSize(16)
        Text(this.statusText)
          .fontSize(16)
          .fontColor(this.getStatusColor())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 设备选择区域
      Column({ space: 10 }) {
        Text('目标设备')
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

        Button('选择设备')
          .onClick(() => {
            // 这里应该打开设备选择页面
            // 示例中模拟选择一个设备
            this.selectedDevice = {
              deviceId: 'test_device_id',
              deviceName: '测试设备',
              deviceType: 'tablet',
              networkId: 'test_network_id'
            };
            constant.showToast('已选择测试设备');
          })
      }
      .width('100%')
      .padding(20)
      .border({ width: 1, color: Color.Gray, radius: 8 })

      // 操作按钮
      Column({ space: 15 }) {
        Row({ space: 20 }) {
          Button('开始穿越')
            .enabled(this.isInitialized && 
                    this.selectedDevice != null && 
                    this.currentStatus === CooperateStatus.IDLE)
            .onClick(() => this.startCooperate())

          Button('停止穿越')
            .enabled(this.isInitialized && 
                    this.currentStatus === CooperateStatus.ACTIVE)
            .onClick(() => this.stopCooperate())
        }

        Button('检查设备支持')
          .enabled(this.isInitialized && this.selectedDevice != null)
          .onClick(() => this.checkDeviceSupport())
      }

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
      }
      .width('100%')
      .padding(15)
      .border({ width: 1, color: Color.Gray, radius: 8 })

      Flex().layoutWeight(1)
    }
    .height('100%')
    .width('100%')
    .padding(20)
  }
}
