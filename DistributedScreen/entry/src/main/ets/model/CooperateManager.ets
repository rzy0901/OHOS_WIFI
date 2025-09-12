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

import cooperateService from './CooperateService';
import {
  CooperateConfig,
  CooperateStatus,
  CooperateEventType,
  CooperateEventListener,
  CooperateStatusInfo,
  MouseLocation,
  DeviceInfo,
  MouseLocationEventData,
  StatusChangeListener,
  MouseLocationListener,
  ErrorListener
} from './CooperateTypes';
import Logger from '../common/Logger';
import { BusinessError } from '@ohos.base';

const TAG: string = '[CooperateManager]';

/**
 * 键鼠穿越管理器 - 提供简化的API接口
 * 这是应用层主要使用的接口类
 */
export class CooperateManager {
  private static instance: CooperateManager | null = null;
  private isServiceInitialized: boolean = false;

  /**
   * 获取单例实例
   */
  public static getInstance(): CooperateManager {
    if (CooperateManager.instance === null) {
      CooperateManager.instance = new CooperateManager();
    }
    return CooperateManager.instance;
  }

  private constructor() {}

  /**
   * 初始化键鼠穿越功能
   * 在使用其他功能前必须先调用此方法
   */
  public async initialize(): Promise<void> {
    if (this.isServiceInitialized) {
      Logger.info(TAG, 'Cooperate manager already initialized');
      return;
    }

    try {
      Logger.info(TAG, 'Initializing cooperate manager...');
      await cooperateService.initialize();
      this.isServiceInitialized = true;
      Logger.info(TAG, 'Cooperate manager initialized successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize cooperate manager: ' + JSON.stringify(error));
      throw new Error('Failed to initialize cooperate manager');
    }
  }

  /**
   * 销毁键鼠穿越功能
   * 释放资源，停止所有监听
   */
  public destroy(): void {
    if (!this.isServiceInitialized) {
      return;
    }

    try {
      Logger.info(TAG, 'Destroying cooperate manager...');
      cooperateService.destroy();
      this.isServiceInitialized = false;
      Logger.info(TAG, 'Cooperate manager destroyed');
    } catch (error) {
      Logger.error(TAG, 'Error destroying cooperate manager: ' + JSON.stringify(error));
    }
  }

  /**
   * 开始键鼠穿越到指定设备
   * @param targetNetworkId 目标设备网络ID
   * @param inputDeviceId 输入设备ID（默认为0）
   */
  public async startCooperate(targetNetworkId: string, inputDeviceId: number = 0): Promise<void> {
    this.ensureInitialized();

    if (!targetNetworkId) {
      throw new Error('Target network ID is required');
    }

    const config: CooperateConfig = {
      targetNetworkId,
      inputDeviceId
    };

    try {
      Logger.info(TAG, `Starting cooperate to device: ${targetNetworkId}`);
      await cooperateService.startCooperate(config);
      Logger.info(TAG, 'Cooperate started successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to start cooperate: ' + JSON.stringify(error));
      throw this.wrapError(error as BusinessError, 'Failed to start keyboard mouse crossing');
    }
  }

  /**
   * 停止键鼠穿越
   * @param disconnectLink 是否断开设备间连接（默认false）
   */
  public async stopCooperate(disconnectLink: boolean = false): Promise<void> {
    this.ensureInitialized();

    try {
      Logger.info(TAG, `Stopping cooperate, disconnect link: ${disconnectLink}`);
      await cooperateService.stopCooperate(disconnectLink);
      Logger.info(TAG, 'Cooperate stopped successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to stop cooperate: ' + JSON.stringify(error));
      throw this.wrapError(error as BusinessError, 'Failed to stop keyboard mouse crossing');
    }
  }

  /**
   * 获取当前键鼠穿越状态
   */
  public getStatus(): CooperateStatus {
    this.ensureInitialized();
    return cooperateService.getCurrentStatus();
  }

  /**
   * 检查当前是否正在进行键鼠穿越
   */
  public isActive(): boolean {
    return this.getStatus() === CooperateStatus.ACTIVE;
  }

  /**
   * 检查当前是否处于连接状态（包括准备、激活等）
   */
  public isConnected(): boolean {
    const status = this.getStatus();
    return status === CooperateStatus.PREPARED || 
           status === CooperateStatus.ACTIVATING || 
           status === CooperateStatus.ACTIVE;
  }

  /**
   * 检查设备是否支持键鼠穿越
   * @param networkId 设备网络ID
   */
  public async isDeviceSupported(networkId: string): Promise<boolean> {
    this.ensureInitialized();

    if (!networkId) {
      throw new Error('Network ID is required');
    }

    try {
      Logger.info(TAG, `Checking device support: ${networkId}`);
      const isSupported = await cooperateService.getDeviceSwitchState(networkId);
      Logger.info(TAG, `Device ${networkId} support status: ${isSupported}`);
      return isSupported;
    } catch (error) {
      Logger.error(TAG, `Failed to check device support: ${JSON.stringify(error)}`);
      throw this.wrapError(error as BusinessError, 'Failed to check device support');
    }
  }

  /**
   * 监听键鼠穿越状态变化
   * @param callback 状态变化回调函数
   */
  public onStatusChanged(callback: StatusChangeListener): void {
    this.ensureInitialized();
    cooperateService.addEventListener(CooperateEventType.STATUS_CHANGED, callback);
  }

  /**
   * 取消监听键鼠穿越状态变化
   * @param callback 要取消的回调函数（可选，不传则取消所有）
   */
  public offStatusChanged(callback?: StatusChangeListener): void {
    if (this.isServiceInitialized) {
      cooperateService.removeEventListener(CooperateEventType.STATUS_CHANGED, callback);
    }
  }

  /**
   * 监听鼠标位置变化
   * @param callback 鼠标位置变化回调函数
   */
  public onMouseLocationChanged(callback: MouseLocationListener): void {
    this.ensureInitialized();
    cooperateService.addEventListener(CooperateEventType.MOUSE_LOCATION_CHANGED, callback);
  }

  /**
   * 取消监听鼠标位置变化
   * @param callback 要取消的回调函数（可选，不传则取消所有）
   */
  public offMouseLocationChanged(callback?: MouseLocationListener): void {
    if (this.isServiceInitialized) {
      cooperateService.removeEventListener(CooperateEventType.MOUSE_LOCATION_CHANGED, callback);
    }
  }

  /**
   * 监听错误事件
   * @param callback 错误事件回调函数
   */
  public onError(callback: ErrorListener): void {
    this.ensureInitialized();
    cooperateService.addEventListener(CooperateEventType.ERROR_OCCURRED, callback);
  }

  /**
   * 取消监听错误事件
   * @param callback 要取消的回调函数（可选，不传则取消所有）
   */
  public offError(callback?: ErrorListener): void {
    if (this.isServiceInitialized) {
      cooperateService.removeEventListener(CooperateEventType.ERROR_OCCURRED, callback);
    }
  }

  /**
   * 开始追踪指定设备的鼠标位置
   * @param networkId 设备网络ID
   */
  public startTrackingMouseLocation(networkId: string): void {
    this.ensureInitialized();

    if (!networkId) {
      throw new Error('Network ID is required');
    }

    try {
      Logger.info(TAG, `Starting mouse tracking for device: ${networkId}`);
      cooperateService.startMouseLocationTracking(networkId);
    } catch (error) {
      Logger.error(TAG, `Failed to start mouse tracking: ${JSON.stringify(error)}`);
      throw this.wrapError(error as BusinessError, 'Failed to start mouse tracking');
    }
  }

  /**
   * 停止追踪指定设备的鼠标位置
   * @param networkId 设备网络ID
   */
  public stopTrackingMouseLocation(networkId: string): void {
    if (!this.isServiceInitialized || !networkId) {
      return;
    }

    try {
      Logger.info(TAG, `Stopping mouse tracking for device: ${networkId}`);
      cooperateService.stopMouseLocationTracking(networkId);
    } catch (error) {
      Logger.error(TAG, `Failed to stop mouse tracking: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 确保服务已初始化
   */
  private ensureInitialized(): void {
    if (!this.isServiceInitialized) {
      throw new Error('Cooperate manager not initialized. Call initialize() first.');
    }
  }

  /**
   * 包装错误信息
   */
  private wrapError(originalError: BusinessError, message: string): Error {
    const error = new Error(`${message}: ${originalError.message || originalError.toString()}`);
    return error;
  }
}

// 导出单例实例，方便直接使用
export default CooperateManager.getInstance();
