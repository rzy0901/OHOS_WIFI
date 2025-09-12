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

/**
 * 键鼠穿越状态枚举
 */
export enum CooperateStatus {
  IDLE = 'idle',                    // 空闲状态
  PREPARING = 'preparing',          // 准备中
  PREPARED = 'prepared',            // 已准备
  ACTIVATING = 'activating',        // 激活中
  ACTIVE = 'active',                // 已激活
  DEACTIVATING = 'deactivating',    // 停止中
  ERROR = 'error'                   // 错误状态
}

/**
 * 键鼠穿越事件类型
 */
export enum CooperateEventType {
  STATUS_CHANGED = 'statusChanged',
  MOUSE_LOCATION_CHANGED = 'mouseLocationChanged',
  ERROR_OCCURRED = 'errorOccurred'
}

/**
 * 鼠标位置信息
 */
export interface MouseLocation {
  displayX: number;         // 鼠标X坐标
  displayY: number;         // 鼠标Y坐标
  displayWidth: number;     // 屏幕宽度
  displayHeight: number;    // 屏幕高度
}

/**
 * 键鼠穿越状态信息
 */
export interface CooperateStatusInfo {
  status: CooperateStatus;
  targetNetworkId?: string;
  inputDeviceId?: number;
  error?: Error;
}

/**
 * 设备信息
 */
export interface DeviceInfo {
  networkId: string;
  deviceName: string;
  deviceType: string;
  isOnline: boolean;
  isTrusted: boolean;
}

/**
 * 鼠标位置事件数据
 */
export interface MouseLocationEventData {
  networkId: string;
  location: MouseLocation;
}

/**
 * 键鼠穿越配置
 */
export interface CooperateConfig {
  targetNetworkId: string;
  inputDeviceId: number;
  isUnchained?: boolean;  // 停止时是否断开跨设备链路，默认false
}

/**
 * 状态变化事件监听器类型
 */
export type StatusChangeListener = (data: CooperateStatusInfo) => void;

/**
 * 鼠标位置变化事件监听器类型
 */
export type MouseLocationListener = (data: MouseLocationEventData) => void;

/**
 * 错误事件监听器类型
 */
export type ErrorListener = (error: Error) => void;

/**
 * 通用事件监听器类型
 */
export type CooperateEventListener = StatusChangeListener | MouseLocationListener | ErrorListener;

/**
 * 键鼠穿越服务接口
 */
export interface ICooperateService {
  /**
   * 初始化服务
   */
  initialize(): Promise<void>;

  /**
   * 销毁服务
   */
  destroy(): void;

  /**
   * 开始键鼠穿越
   * @param config 配置信息
   */
  startCooperate(config: CooperateConfig): Promise<void>;

  /**
   * 停止键鼠穿越
   * @param isUnchained 是否断开跨设备链路
   */
  stopCooperate(isUnchained?: boolean): Promise<void>;

  /**
   * 获取当前状态
   */
  getCurrentStatus(): CooperateStatus;

  /**
   * 获取设备的键鼠穿越开关状态
   * @param networkId 设备网络ID
   */
  getDeviceSwitchState(networkId: string): Promise<boolean>;

  /**
   * 添加事件监听器
   * @param eventType 事件类型
   * @param listener 监听器
   */
  addEventListener(eventType: CooperateEventType, listener: CooperateEventListener): void;

  /**
   * 移除事件监听器
   * @param eventType 事件类型
   * @param listener 监听器
   */
  removeEventListener(eventType: CooperateEventType, listener?: CooperateEventListener): void;

  /**
   * 开始监听指定设备的鼠标位置
   * @param networkId 设备网络ID
   */
  startMouseLocationTracking(networkId: string): void;

  /**
   * 停止监听指定设备的鼠标位置
   * @param networkId 设备网络ID
   */
  stopMouseLocationTracking(networkId: string): void;
}
