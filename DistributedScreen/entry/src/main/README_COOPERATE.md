# 键鼠穿越功能使用指南

本文档介绍如何在您的应用中使用键鼠穿越功能。

## 概述

键鼠穿越功能允许用户在多台设备之间共享键盘和鼠标，实现跨设备的无缝操作。本实现封装了 HarmonyOS 的 `@ohos.cooperate` 系统接口，提供了简洁易用的API。

## 主要组件

1. **CooperateTypes.ets** - 类型定义和接口
2. **CooperateService.ets** - 底层服务实现
3. **CooperateManager.ets** - 应用层管理器（推荐使用）
4. **CooperateExample.ets** - 使用示例

## 快速开始

### 1. 导入管理器

```typescript
import cooperateManager from '../model/CooperateManager';
import { CooperateStatus } from '../model/CooperateTypes';
```

### 2. 初始化

```typescript
// 在页面或组件的 aboutToAppear 中初始化
async aboutToAppear() {
  try {
    await cooperateManager.initialize();
    console.log('键鼠穿越功能初始化成功');
  } catch (error) {
    console.error('初始化失败:', error.message);
  }
}
```

### 3. 开始键鼠穿越

```typescript
async function startCooperate() {
  try {
    const targetNetworkId = 'target_device_network_id'; // 目标设备的网络ID
    await cooperateManager.startCooperate(targetNetworkId);
    console.log('键鼠穿越启动成功');
  } catch (error) {
    console.error('启动失败:', error.message);
  }
}
```

### 4. 停止键鼠穿越

```typescript
async function stopCooperate() {
  try {
    await cooperateManager.stopCooperate();
    console.log('键鼠穿越已停止');
  } catch (error) {
    console.error('停止失败:', error.message);
  }
}
```

### 5. 监听状态变化

```typescript
// 监听状态变化
cooperateManager.onStatusChanged((statusInfo) => {
  console.log('状态变化:', statusInfo.status);
  switch (statusInfo.status) {
    case CooperateStatus.ACTIVE:
      console.log('键鼠穿越已激活');
      break;
    case CooperateStatus.IDLE:
      console.log('键鼠穿越已停止');
      break;
    // 其他状态...
  }
});

// 监听错误事件
cooperateManager.onError((error) => {
  console.error('键鼠穿越错误:', error.message);
});
```

### 6. 清理资源

```typescript
// 在页面或组件的 aboutToDisappear 中清理
aboutToDisappear() {
  cooperateManager.destroy();
}
```

## API 参考

### CooperateManager 主要方法

#### `initialize(): Promise<void>`
初始化键鼠穿越功能。

#### `destroy(): void`
销毁功能，释放资源。

#### `startCooperate(targetNetworkId: string, inputDeviceId?: number): Promise<void>`
开始键鼠穿越。
- `targetNetworkId`: 目标设备网络ID
- `inputDeviceId`: 输入设备ID（可选，默认0）

#### `stopCooperate(disconnectLink?: boolean): Promise<void>`
停止键鼠穿越。
- `disconnectLink`: 是否断开设备间连接（可选，默认false）

#### `getStatus(): CooperateStatus`
获取当前状态。

#### `isActive(): boolean`
检查是否正在进行键鼠穿越。

#### `isDeviceSupported(networkId: string): Promise<boolean>`
检查设备是否支持键鼠穿越。

### 事件监听

#### `onStatusChanged(callback): void`
监听状态变化。

#### `onMouseLocationChanged(callback): void`
监听鼠标位置变化。

#### `onError(callback): void`
监听错误事件。

#### `startTrackingMouseLocation(networkId: string): void`
开始追踪指定设备的鼠标位置。

#### `stopTrackingMouseLocation(networkId: string): void`
停止追踪指定设备的鼠标位置。

### 状态说明

```typescript
enum CooperateStatus {
  IDLE = 'idle',                    // 空闲状态
  PREPARING = 'preparing',          // 准备中
  PREPARED = 'prepared',            // 已准备
  ACTIVATING = 'activating',        // 激活中
  ACTIVE = 'active',                // 已激活
  DEACTIVATING = 'deactivating',    // 停止中
  ERROR = 'error'                   // 错误状态
}
```

## 完整示例

```typescript
import cooperateManager from '../model/CooperateManager';
import { CooperateStatus, CooperateStatusInfo } from '../model/CooperateTypes';

@Entry
@Component
struct MyCooperatePage {
  @State currentStatus: CooperateStatus = CooperateStatus.IDLE;
  @State targetDevice: string = '';

  async aboutToAppear() {
    // 初始化
    await cooperateManager.initialize();
    
    // 设置监听器
    cooperateManager.onStatusChanged(this.onStatusChanged);
    cooperateManager.onError(this.onError);
  }

  aboutToDisappear() {
    // 清理资源
    cooperateManager.destroy();
  }

  private onStatusChanged = (statusInfo: CooperateStatusInfo) => {
    this.currentStatus = statusInfo.status;
  }

  private onError = (error: Error) => {
    console.error('错误:', error.message);
  }

  private async handleStart() {
    if (!this.targetDevice) {
      console.error('请先选择目标设备');
      return;
    }
    
    try {
      await cooperateManager.startCooperate(this.targetDevice);
    } catch (error) {
      console.error('启动失败:', error.message);
    }
  }

  private async handleStop() {
    try {
      await cooperateManager.stopCooperate();
    } catch (error) {
      console.error('停止失败:', error.message);
    }
  }

  build() {
    Column({ space: 20 }) {
      Text('当前状态: ' + this.currentStatus)
        .fontSize(16)

      Button('开始键鼠穿越')
        .enabled(this.currentStatus === CooperateStatus.IDLE)
        .onClick(() => this.handleStart())

      Button('停止键鼠穿越')
        .enabled(this.currentStatus === CooperateStatus.ACTIVE)
        .onClick(() => this.handleStop())
    }
    .height('100%')
    .width('100%')
    .padding(20)
  }
}
```

## 注意事项

1. **权限要求**: 确保应用已申请 `ohos.permission.COOPERATE_MANAGER` 权限
2. **设备要求**: 目标设备必须支持键鼠穿越功能
3. **网络要求**: 设备需要在同一网络中并已建立信任关系
4. **资源管理**: 及时调用 `destroy()` 方法释放资源
5. **错误处理**: 建议监听错误事件并进行适当的错误处理
6. **状态管理**: 根据当前状态来控制UI的可用性

## 故障排除

### 常见错误

1. **"Service not initialized"**: 请先调用 `initialize()` 方法
2. **"Permission denied"**: 检查应用权限配置
3. **"Device not supported"**: 目标设备不支持键鼠穿越
4. **"Operation failed"**: 检查设备连接状态和网络

### 调试建议

1. 检查设备管理器中是否有可用设备
2. 确认设备间已建立信任关系
3. 查看日志输出了解详细错误信息
4. 确保目标设备的键鼠穿越开关已开启

## 版本要求

- HarmonyOS API 11+
- 支持键鼠穿越的设备
