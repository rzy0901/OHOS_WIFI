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

import cooperate from '@ohos.cooperate';
import { BusinessError } from '@ohos.base';
import Logger from '../common/Logger';
import {
  ICooperateService,
  CooperateConfig,
  CooperateStatus,
  CooperateEventType,
  CooperateEventListener,
  CooperateStatusInfo,
  MouseLocation,
  MouseLocationEventData,
  StatusChangeListener,
  MouseLocationListener,
  ErrorListener
} from './CooperateTypes';

const TAG: string = '[CooperateService]';

/**
 * 键鼠穿越服务实现类
 */
export class CooperateService implements ICooperateService {
  private static instance: CooperateService | null = null;
  private currentStatus: CooperateStatus = CooperateStatus.IDLE;
  private currentConfig: CooperateConfig | null = null;
  private statusListeners: StatusChangeListener[] = [];
  private mouseLocationListeners: MouseLocationListener[] = [];
  private errorListeners: ErrorListener[] = [];
  private isInitialized: boolean = false;
  private mouseTrackingDevices: Set<string> = new Set();

  /**
   * 获取单例实例
   */
  public static getInstance(): CooperateService {
    if (CooperateService.instance === null) {
      CooperateService.instance = new CooperateService();
    }
    return CooperateService.instance;
  }

  private constructor() {
    this.initEventListeners();
  }

  /**
   * 初始化事件监听器映射
   */
  private initEventListeners(): void {
    this.statusListeners = [];
    this.mouseLocationListeners = [];
    this.errorListeners = [];
  }

  /**
   * 初始化服务
   */
  public async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(TAG, 'Service already initialized');
      return;
    }

    try {
      Logger.info(TAG, 'Initializing cooperate service...');
      
      // 注册键鼠穿越状态监听
      this.registerCooperateMessageListener();
      
      this.isInitialized = true;
      Logger.info(TAG, 'Cooperate service initialized successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize cooperate service: ' + JSON.stringify(error));
      this.emitErrorEvent(error as Error);
      throw new Error('Failed to initialize cooperate service');
    }
  }

  /**
   * 销毁服务
   */
  public destroy(): void {
    try {
      Logger.info(TAG, 'Destroying cooperate service...');
      
      // 如果正在穿越，先停止
      if (this.currentStatus === CooperateStatus.ACTIVE) {
        this.stopCooperate(false).catch((error: Error) => {
          Logger.error(TAG, 'Error stopping cooperate during destroy: ' + JSON.stringify(error));
        });
      }

      // 取消所有事件监听
      this.unregisterCooperateMessageListener();
      this.stopAllMouseLocationTracking();
      
      // 清空事件监听器
      this.statusListeners = [];
      this.mouseLocationListeners = [];
      this.errorListeners = [];
      
      this.isInitialized = false;
      this.currentStatus = CooperateStatus.IDLE;
      this.currentConfig = null;
      
      Logger.info(TAG, 'Cooperate service destroyed');
    } catch (error) {
      Logger.error(TAG, 'Error destroying cooperate service: ' + JSON.stringify(error));
    }
  }

  /**
   * 开始键鼠穿越
   */
  public async startCooperate(config: CooperateConfig): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('Service not initialized. Call initialize() first.');
    }

    if (this.currentStatus === CooperateStatus.ACTIVE) {
      throw new Error('Cooperate is already active');
    }

    if (this.currentStatus === CooperateStatus.ACTIVATING) {
      throw new Error('Cooperate is already activating');
    }

    try {
      Logger.info(TAG, 'Starting cooperate with config: ' + JSON.stringify(config));
      
      this.currentConfig = config;
      this.updateStatus(CooperateStatus.PREPARING);

      // 准备键鼠穿越
      await cooperate.prepareCooperate();
      Logger.info(TAG, 'Cooperate prepared successfully');
      
      this.updateStatus(CooperateStatus.PREPARED);

      // 启动键鼠穿越
      this.updateStatus(CooperateStatus.ACTIVATING);
      await cooperate.activateCooperate(config.targetNetworkId, config.inputDeviceId);
      
      this.updateStatus(CooperateStatus.ACTIVE);
      Logger.info(TAG, 'Cooperate started successfully');
      
    } catch (error) {
      Logger.error(TAG, 'Failed to start cooperate: ' + JSON.stringify(error));
      this.updateStatus(CooperateStatus.ERROR);
      this.emitErrorEvent(error as Error);
      throw new Error('Failed to start cooperate');
    }
  }

  /**
   * 停止键鼠穿越
   */
  public async stopCooperate(isUnchained: boolean = false): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('Service not initialized');
    }

    if (this.currentStatus === CooperateStatus.IDLE) {
      Logger.info(TAG, 'Cooperate is already stopped');
      return;
    }

    if (this.currentStatus === CooperateStatus.DEACTIVATING) {
      throw new Error('Cooperate is already deactivating');
    }

    try {
      Logger.info(TAG, 'Stopping cooperate, isUnchained: ' + isUnchained);
      
      this.updateStatus(CooperateStatus.DEACTIVATING);

      // 停止键鼠穿越
      await cooperate.deactivateCooperate(isUnchained);
      Logger.info(TAG, 'Cooperate deactivated successfully');

      // 取消准备
      await cooperate.unprepareCooperate();
      Logger.info(TAG, 'Cooperate unprepared successfully');

      this.updateStatus(CooperateStatus.IDLE);
      this.currentConfig = null;
      
      Logger.info(TAG, 'Cooperate stopped successfully');
      
    } catch (error) {
      Logger.error(TAG, 'Failed to stop cooperate: ' + JSON.stringify(error));
      this.updateStatus(CooperateStatus.ERROR);
      this.emitErrorEvent(error as Error);
      throw new Error('Failed to stop cooperate');
    }
  }

  /**
   * 获取当前状态
   */
  public getCurrentStatus(): CooperateStatus {
    return this.currentStatus;
  }

  /**
   * 获取设备的键鼠穿越开关状态
   */
  public async getDeviceSwitchState(networkId: string): Promise<boolean> {
    if (!this.isInitialized) {
      throw new Error('Service not initialized');
    }

    try {
      Logger.info(TAG, 'Getting device switch state for: ' + networkId);
      const state = await cooperate.getCooperateSwitchState(networkId);
      Logger.info(TAG, 'Device switch state: ' + state);
      return state;
    } catch (error) {
      Logger.error(TAG, 'Failed to get device switch state: ' + JSON.stringify(error));
      this.emitErrorEvent(error as Error);
      throw new Error('Failed to get device switch state');
    }
  }

  /**
   * 添加事件监听器
   */
  public addEventListener(eventType: CooperateEventType, listener: CooperateEventListener): void {
    switch (eventType) {
      case CooperateEventType.STATUS_CHANGED:
        const statusListener = listener as StatusChangeListener;
        if (!this.statusListeners.includes(statusListener)) {
          this.statusListeners.push(statusListener);
          Logger.info(TAG, 'Added status event listener');
        }
        break;
      case CooperateEventType.MOUSE_LOCATION_CHANGED:
        const mouseListener = listener as MouseLocationListener;
        if (!this.mouseLocationListeners.includes(mouseListener)) {
          this.mouseLocationListeners.push(mouseListener);
          Logger.info(TAG, 'Added mouse location event listener');
        }
        break;
      case CooperateEventType.ERROR_OCCURRED:
        const errorListener = listener as ErrorListener;
        if (!this.errorListeners.includes(errorListener)) {
          this.errorListeners.push(errorListener);
          Logger.info(TAG, 'Added error event listener');
        }
        break;
    }
  }

  /**
   * 移除事件监听器
   */
  public removeEventListener(eventType: CooperateEventType, listener?: CooperateEventListener): void {
    switch (eventType) {
      case CooperateEventType.STATUS_CHANGED:
        if (listener) {
          const statusListener = listener as StatusChangeListener;
          const index = this.statusListeners.indexOf(statusListener);
          if (index > -1) {
            this.statusListeners.splice(index, 1);
            Logger.info(TAG, 'Removed specific status event listener');
          }
        } else {
          this.statusListeners = [];
          Logger.info(TAG, 'Removed all status event listeners');
        }
        break;
      case CooperateEventType.MOUSE_LOCATION_CHANGED:
        if (listener) {
          const mouseListener = listener as MouseLocationListener;
          const index = this.mouseLocationListeners.indexOf(mouseListener);
          if (index > -1) {
            this.mouseLocationListeners.splice(index, 1);
            Logger.info(TAG, 'Removed specific mouse location event listener');
          }
        } else {
          this.mouseLocationListeners = [];
          Logger.info(TAG, 'Removed all mouse location event listeners');
        }
        break;
      case CooperateEventType.ERROR_OCCURRED:
        if (listener) {
          const errorListener = listener as ErrorListener;
          const index = this.errorListeners.indexOf(errorListener);
          if (index > -1) {
            this.errorListeners.splice(index, 1);
            Logger.info(TAG, 'Removed specific error event listener');
          }
        } else {
          this.errorListeners = [];
          Logger.info(TAG, 'Removed all error event listeners');
        }
        break;
    }
  }

  /**
   * 开始监听指定设备的鼠标位置
   */
  public startMouseLocationTracking(networkId: string): void {
    if (!this.isInitialized) {
      throw new Error('Service not initialized');
    }

    if (this.mouseTrackingDevices.has(networkId)) {
      Logger.info(TAG, 'Already tracking mouse location for device: ' + networkId);
      return;
    }

    try {
      Logger.info(TAG, 'Starting mouse location tracking for device: ' + networkId);
      
      cooperate.on('cooperateMouse', networkId, (location: MouseLocation) => {
        this.emitMouseLocationEvent(networkId, location);
      });
      
      this.mouseTrackingDevices.add(networkId);
      Logger.info(TAG, 'Started mouse location tracking for device: ' + networkId);
      
    } catch (error) {
      Logger.error(TAG, 'Failed to start mouse location tracking: ' + JSON.stringify(error));
      this.emitErrorEvent(error as Error);
      throw new Error('Failed to start mouse location tracking');
    }
  }

  /**
   * 停止监听指定设备的鼠标位置
   */
  public stopMouseLocationTracking(networkId: string): void {
    if (!this.mouseTrackingDevices.has(networkId)) {
      Logger.info(TAG, 'Not tracking mouse location for device: ' + networkId);
      return;
    }

    try {
      Logger.info(TAG, 'Stopping mouse location tracking for device: ' + networkId);
      
      cooperate.off('cooperateMouse', networkId);
      this.mouseTrackingDevices.delete(networkId);
      
      Logger.info(TAG, 'Stopped mouse location tracking for device: ' + networkId);
      
    } catch (error) {
      Logger.error(TAG, 'Failed to stop mouse location tracking: ' + JSON.stringify(error));
      this.emitErrorEvent(error as Error);
    }
  }

  /**
   * 停止所有鼠标位置监听
   */
  private stopAllMouseLocationTracking(): void {
    for (const networkId of this.mouseTrackingDevices) {
      this.stopMouseLocationTracking(networkId);
    }
    this.mouseTrackingDevices.clear();
  }

  /**
   * 注册键鼠穿越状态监听
   */
  private registerCooperateMessageListener(): void {
    try {
      cooperate.on('cooperateMessage', (message: cooperate.CooperateMessage) => {
        Logger.info(TAG, 'Received cooperate message: ' + JSON.stringify(message));
        this.handleCooperateMessage(message);
      });
      Logger.info(TAG, 'Registered cooperate message listener');
    } catch (error) {
      Logger.error(TAG, 'Failed to register cooperate message listener: ' + JSON.stringify(error));
      throw new Error('Failed to register cooperate message listener');
    }
  }

  /**
   * 取消键鼠穿越状态监听
   */
  private unregisterCooperateMessageListener(): void {
    try {
      cooperate.off('cooperateMessage');
      Logger.info(TAG, 'Unregistered cooperate message listener');
    } catch (error) {
      Logger.error(TAG, 'Failed to unregister cooperate message listener: ' + JSON.stringify(error));
    }
  }

  /**
   * 处理键鼠穿越消息
   */
  private handleCooperateMessage(message: cooperate.CooperateMessage): void {
    const networkId = message.networkId;
    const state = message.state;
    Logger.info(TAG, `Handling cooperate message: networkId=${networkId}, state=${state}`);

    switch (state) {
      case cooperate.CooperateState.COOPERATE_PREPARE:
        this.updateStatus(CooperateStatus.PREPARING);
        break;
      case cooperate.CooperateState.COOPERATE_UNPREPARE:
        this.updateStatus(CooperateStatus.IDLE);
        break;
      case cooperate.CooperateState.COOPERATE_ACTIVATE:
        this.updateStatus(CooperateStatus.ACTIVATING);
        break;
      case cooperate.CooperateState.COOPERATE_ACTIVATE_SUCCESS:
        this.updateStatus(CooperateStatus.ACTIVE);
        break;
      case cooperate.CooperateState.COOPERATE_ACTIVATE_FAILURE:
        this.updateStatus(CooperateStatus.ERROR);
        this.emitErrorEvent(new Error('Failed to activate cooperate'));
        break;
      case cooperate.CooperateState.COOPERATE_DEACTIVATE_SUCCESS:
        this.updateStatus(CooperateStatus.DEACTIVATING);
        break;
      case cooperate.CooperateState.COOPERATE_DEACTIVATE_FAILURE:
        this.updateStatus(CooperateStatus.ERROR);
        this.emitErrorEvent(new Error('Failed to deactivate cooperate'));
        break;
      case cooperate.CooperateState.COOPERATE_SESSION_DISCONNECTED:
        this.updateStatus(CooperateStatus.IDLE);
        this.currentConfig = null;
        break;
      default:
        Logger.warn(TAG, 'Unknown cooperate state: ' + state);
        break;
    }
  }

  /**
   * 更新状态并触发事件
   */
  private updateStatus(newStatus: CooperateStatus): void {
    if (this.currentStatus !== newStatus) {
      const oldStatus = this.currentStatus;
      this.currentStatus = newStatus;
      
      Logger.info(TAG, `Status changed: ${oldStatus} -> ${newStatus}`);
      
      const statusInfo: CooperateStatusInfo = {
        status: newStatus,
        targetNetworkId: this.currentConfig?.targetNetworkId,
        inputDeviceId: this.currentConfig?.inputDeviceId
      };
      
      this.emitStatusEvent(statusInfo);
    }
  }

  /**
   * 触发状态变化事件
   */
  private emitStatusEvent(statusInfo: CooperateStatusInfo): void {
    this.statusListeners.forEach(listener => {
      try {
        listener(statusInfo);
      } catch (error) {
        Logger.error(TAG, 'Error in status event listener: ' + JSON.stringify(error));
      }
    });
  }

  /**
   * 触发鼠标位置事件
   */
  private emitMouseLocationEvent(networkId: string, location: MouseLocation): void {
    const eventData: MouseLocationEventData = { 
      networkId: networkId, 
      location: location 
    };
    
    this.mouseLocationListeners.forEach(listener => {
      try {
        listener(eventData);
      } catch (error) {
        Logger.error(TAG, 'Error in mouse location event listener: ' + JSON.stringify(error));
      }
    });
  }

  /**
   * 触发错误事件
   */
  private emitErrorEvent(error: Error): void {
    this.errorListeners.forEach(listener => {
      try {
        listener(error);
      } catch (error) {
        Logger.error(TAG, 'Error in error event listener: ' + JSON.stringify(error));
      }
    });
  }
}

// 导出单例实例
export default CooperateService.getInstance();
