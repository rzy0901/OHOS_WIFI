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

import screen from '@ohos.screen';
import constant from '../common/Constant';
import Logger from '../common/Logger';
import router from '@ohos.router';
import display from '@ohos.display';
import deviceManager from '@ohos.distributedDeviceManager';
import { RemoteDeviceModel } from '../model/RemoteDeviceModel';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import { mediaquery } from '@kit.ArkUI';
import cooperateManager from '../model/CooperateManager';
import { CooperateStatus, CooperateStatusInfo, MouseLocationEventData } from '../model/CooperateTypes';

const TAG: string = '[Index]'

@Entry
@Component
struct Index {
  private screenWidth: number = 720;
  private screenHeight: number = 1280;
  private allScreens: Array <screen.Screen> = [];
  private virtualScreenId: number = -1;
  private debounceFlag = true;
  @State private enableVirtualScreen: boolean = false;
  private noFoundScreen: string = '';
  private notStarted: string = '';
  @State private isStarted: boolean = false;
  @State isStartClick: boolean = false;
  @State isStopClick: boolean = false;
  private virtualScreenWidth: number = 0;
  private virtualScreenHeight: number = 0;
  private xcomponentController: XComponentController  | undefined = undefined;
  @State isLandscape: boolean = true;
  private listener = mediaquery.matchMediaSync('screen and (min-aspect-ratio:1.5)');
  
  // 键鼠穿越相关状态
  @State cooperateStatus: CooperateStatus = CooperateStatus.IDLE;
  @State isCooperateStartClick: boolean = false;
  @State isCooperateStopClick: boolean = false;
  @State selectedDeviceForCooperate: deviceManager.DeviceBasicInfo | null = null;
  @State isCooperateInitialized: boolean = false;
  private remoteDeviceModel: RemoteDeviceModel = RemoteDeviceModel.getInstance();

  @Styles pressedStyles() {
    .borderRadius(5)
    .width(60)
    .height(60)
    .backgroundColor($r('app.color.white'))
    .bindMenu(this.IndexMenu)
  }

  async routeDeviceManagerPage() {
    let options: router.RouterOptions = {
      url: 'pages/DeviceManager',
    };
    try {
      await router.pushUrl(options);
    } catch (err) {
      Logger.info(TAG, `fail callback, code: ${err.code}, msg: ${err.msg}`);
    }
  }

  async routeCooperateTestPage() {
    let options: router.RouterOptions = {
      url: 'pages/CooperateTest',
    };
    try {
      await router.pushUrl(options);
    } catch (err) {
      Logger.info(TAG, `fail callback, code: ${err.code}, msg: ${err.msg}`);
    }
  }

  createVirtualScreen(surfaceId :string) {
    Logger.info(TAG, 'createVirtualScreen')
    try {
      screen.createVirtualScreen({
        name: 'screen01',
        width: this.virtualScreenWidth,
        height: this.virtualScreenHeight,
        density: 2,
        surfaceId: surfaceId
      }).then((screen) => {
        this.virtualScreenId = screen.id
        console.info('Succeeded in creating the virtual screen. Data: ' + JSON.stringify(screen));
      }).catch((err: BusinessError) => {
        console.error('Failed to create the virtual screen. Code: ' + JSON.stringify(err));
      });
    } catch (exception) {
      console.error('Failed to set the surface for the virtual screen. Code: ' + JSON.stringify(exception));
    }
  }

  destroyVirtualScreen() {
    try {
      if (this.virtualScreenId != -1) {
        screen.destroyVirtualScreen(this.virtualScreenId).then(() => {
          console.info('Succeeded in destroy the virtual screen.');
          this.virtualScreenId = -1;
        }).catch((err: string) => {
          console.error('Failed to destroy the virtual screen.');
        });
      }
    } catch (exception) {
      console.error('Failed to set the surface for the virtual screen. Code: ' + JSON.stringify(exception));
    }
  }

  onPortrait(mediaQueryResult:mediaquery.MediaQueryResult) {
    if (mediaQueryResult.matches) {
      this.isLandscape = true;
    } else {
      this.isLandscape = false;
    }
  }

  async aboutToAppear() {
    Logger.info(TAG, 'aboutToAppear')
    let portraitFunc = (mediaQueryResult: mediaquery.MediaQueryResult): void => this.onPortrait(mediaQueryResult)
    this.listener.on('change', portraitFunc);
    this.xcomponentController = new XComponentController();
    
    // 初始化键鼠穿越功能
    await this.initCooperateManager();
    let promise = screen.getAllScreens();
    promise.then((data) => {
      this.virtualScreenWidth = data[0].supportedModeInfo[0].width * 3 / 4;
      this.virtualScreenHeight = data[0].supportedModeInfo[0].height * 3 / 4;
      Logger.info(TAG, 'Succeeded in getting all screens. Data:' + JSON.stringify(data));
    }).catch((err: string) => {
      Logger.info(TAG, 'Failed to get all screens. Cause: ' + JSON.stringify(err));
    })

    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      this.screenWidth = displayClass.width;
      this.screenHeight = displayClass.height;
    } catch (exception) {
      Logger.error(TAG, 'Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
    }
    Logger.info(TAG, 'Screen width: ' + this.screenWidth + ', height: ' + this.screenHeight);

    try {
      let connectCallback = (data: number) => {
        Logger.info(TAG, 'screen connect. Data: ' + JSON.stringify(data))
      };
      screen.on('connect', connectCallback);
    } catch (exception) {
      Logger.error(TAG, 'screen connect. Code: ' + JSON.stringify(exception));
    }

    try {
      let disconnectCallback = (data: number) => {
        Logger.info(TAG, 'screen disconnect. Data: ' + JSON.stringify(data))
      };
      screen.on('disconnect', disconnectCallback);
    } catch (exception) {
      Logger.error(TAG, 'screen disconnect changes. Code: ' + JSON.stringify(exception));
    }

    try {
      let changeCallback = (data: number) => {
        Logger.info(TAG, 'screen change. Data: ' + JSON.stringify(data))
      };
      screen.on('change', changeCallback);
    } catch (exception) {
      Logger.error(TAG, 'screen change. Code: ' + JSON.stringify(exception));
    }

    let resourceManager = getContext(this).resourceManager;
    resourceManager.getStringValue($r('app.string.no_found_screen').id).then((value : string) => {
      this.noFoundScreen = value;
    });
    resourceManager.getStringValue($r('app.string.not_started').id).then((value : string) => {
      this.notStarted = value;
    });
  }

  aboutToDisappear() {
    Logger.info(TAG, 'aboutToDisappear')
    this.destroyVirtualScreen();
    this.listener.off('change');
    
    // 清理键鼠穿越资源
    this.cleanupCooperateManager();
  }

  onPageShow() {
    Logger.info(TAG, 'onPageShow')
    let promise = screen.getAllScreens();
    promise.then((data) => {
      this.allScreens = data;
      Logger.info(TAG, 'Succeeded in getting all screens. Data:' + JSON.stringify(data));
    }).catch((err: string) => {
      Logger.info(TAG, 'Failed to get all screens. Cause: ' + JSON.stringify(err));
    })
  }

  makeScreenMirror() {
    Logger.info(TAG, 'makeScreenMirror')
    let mainScreenId = 0;
    let mirrorScreenIds: Array<number> = [];

    if (this.enableVirtualScreen) {
      mirrorScreenIds.push(this.virtualScreenId);
    }

    for (let i = this.allScreens.length - 1; i >= 0; i--) {
      if ((this.allScreens[i].id != 0) && (this.allScreens[i].id != 1)) {
        for (let j = this.allScreens[i].supportedModeInfo.length - 1; j >= 0; j--) {
          Logger.info(TAG, "this.screen: " + this.screenWidth + "x" + this.screenHeight + ", supportedModeInfo:" + this.allScreens[i].supportedModeInfo[j].width + "x" + this.allScreens[i].supportedModeInfo[j].height);
        }
      }
    }

    for (let i = this.allScreens.length - 1; i >= 0; i--) {
      Logger.info(TAG, 'id : ' + this.allScreens[i].id);
      if ((this.allScreens[i].id != 0) && (this.allScreens[i].id != 1)) {
        for (let j = this.allScreens[i].supportedModeInfo.length - 1; j >= 0; j--) {
          Logger.info(TAG, 'width : ' + this.allScreens[i].supportedModeInfo[j].width);
          Logger.info(TAG, 'height : ' + this.allScreens[i].supportedModeInfo[j].height);
        }
        Logger.info(TAG, 'makeScreenMirror id : ' + this.allScreens[i].id);
        mirrorScreenIds.push(this.allScreens[i].id);
      }
    }

    if (mirrorScreenIds.length == 0) {
      this.isStarted = false;
      let promise = screen.getAllScreens();
      promise.then((data) => {
        this.allScreens = data;
        Logger.info(TAG, 'Succeeded in getting all screens. Data:' + JSON.stringify(data));
      }).catch((err: string) => {
        Logger.info(TAG, 'Failed to get all screens. Cause: ' + JSON.stringify(err));
      })
      constant.showToast(this.noFoundScreen);
      return;
    }

    try {
      Logger.info(TAG, 'mirrorScreenIds:' + JSON.stringify(mirrorScreenIds))
      screen.makeMirror(mainScreenId, mirrorScreenIds, (err, data) => {
        if (err.code) {
          constant.showToast("Failed to makeMirror")
          console.error('Failed to set screen mirroring. Code: ' + JSON.stringify(err));
          return;
        }
        constant.showToast("Succeeded to makeMirror")
        console.info('Succeeded in setting screen mirroring. Data: ' + JSON.stringify(data));
      });
    } catch (exception) {
      constant.showToast("Failed to makeMirror")
      console.error('Failed to set screen mirroring. Code: ' + JSON.stringify(exception));
    }
  }

  makeMirrorStop() {
    Logger.info(TAG, 'makeMirrorStop');

    try {
      let mirrorScreenIds: Array<number> = [];
      for (let i = this.allScreens.length - 1; i >= 0; i--) {
        if ((this.allScreens[i].id != 0) && (this.allScreens[i].id != 1)) {
            Logger.info(TAG, 'makeMirrorStop id : ' + this.allScreens[i].id);
            mirrorScreenIds.push(this.allScreens[i].id);
        }
      }

      screen.stopMirror(mirrorScreenIds, (err: BusinessError) => {
        const errCode: number = err.code;
        if (errCode) {
          console.error('Failed to stop mirror screens. Code:' + JSON.stringify(err));
          return;
        }
        console.info('Succeeded in stopping mirror screens.');
      });
    } catch (exception) {
      console.error('Failed to stop expand mirror. Code: ' + JSON.stringify(exception));
    };
  }

  switchMirrorFunction() {
    if (this.debounceFlag) {
      this.debounceFlag = false;
      this.isStartClick = true;
      setTimeout(() => {
        this.isStartClick = false;
      }, 2000);

      if (!this.isStarted) {
        this.isStarted = true;
        this.makeScreenMirror();
      }

      setTimeout(() => {
        this.debounceFlag = true;
      }, 2000);
    } else {
      promptAction.showToast({
        message: '点击太快,暂停一下',
        duration: 1000,
      });
    }
  }

  makeScreenExpand() {
    Logger.info(TAG, 'makeScreenExpand')
    let mainScreenId = 0;
    let startX = 0;
    let startY = 0;
    let expandExpandOption: Array<screen.ExpandOption> = [];

    expandExpandOption.push({ screenId: mainScreenId, startX: 0, startY: 0 });

    if (this.enableVirtualScreen) {
      expandExpandOption.push({ screenId: this.virtualScreenId, startX: startX, startY: startY });
    }

    for (let i = this.allScreens.length - 1; i >= 0; i--) {
      if ((this.allScreens[i].id != 0) && (this.allScreens[i].id != 1)) {
        expandExpandOption.push({ screenId: this.allScreens[i].id, startX: startX, startY: startY });
      }
    }

    if (expandExpandOption.length <= 1) {
      this.isStarted = false;
      constant.showToast(this.noFoundScreen);
      return;
    }

    try {
      screen.makeExpand(expandExpandOption)
        .then((data) => {
          constant.showToast("Succeeded to makeExpand")
          console.info('Succeeded in expanding the screen. Data: ' + JSON.stringify(data));
        })
        .catch((err: string) => {
          constant.showToast("Failed to makeExpand")
          console.error('Failed to expand the screen. Code:' + JSON.stringify(err));
        });
    } catch (exception) {
      constant.showToast("Failed to makeExpand")
      console.error('Failed to expand the screen. Code: ' + JSON.stringify(exception));
    }
  }

  makeExpandStop() {
    Logger.info(TAG, 'makeExpandStop')

    try {
      let expandScreenIds: Array<number> = [];
      for (let i = this.allScreens.length - 1; i >= 0; i--) {
        if ((this.allScreens[i].id != 0) && (this.allScreens[i].id != 1)) {
          expandScreenIds.push(this.allScreens[i].id);
        }
      }

      screen.stopExpand(expandScreenIds, (err: BusinessError) => {
        const errCode: number = err.code;
        if (errCode) {
          console.error('Failed to stop expand screens. Code:' + JSON.stringify(err));
          return;
        }
        console.info('Succeeded in stopping expand screens.');
      });
    } catch (exception) {
      console.error('Failed to stop expand screens. Code: ' + JSON.stringify(exception));
    };
  }

  // ========== 键鼠穿越相关方法 ==========
  
  /**
   * 初始化键鼠穿越管理器
   */
  private async initCooperateManager(): Promise<void> {
    try {
      Logger.info(TAG, 'Initializing cooperate manager...');
      await cooperateManager.initialize();
      
      // 设置状态监听
      cooperateManager.onStatusChanged((statusInfo) => {
        this.cooperateStatus = statusInfo.status;
        Logger.info(TAG, 'Cooperate status changed: ' + statusInfo.status);
      });
      
      // 设置错误监听
      cooperateManager.onError((error) => {
        Logger.error(TAG, 'Cooperate error: ' + error.message);
        constant.showToast('键鼠穿越错误: ' + error.message);
      });
      
      this.cooperateStatus = cooperateManager.getStatus();
      this.isCooperateInitialized = true;
      Logger.info(TAG, 'Cooperate manager initialized successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize cooperate manager: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('键鼠穿越初始化失败: ' + errorMessage);
      this.isCooperateInitialized = false;
    }
  }

  /**
   * 清理键鼠穿越管理器
   */
  private cleanupCooperateManager(): void {
    try {
      cooperateManager.destroy();
      this.isCooperateInitialized = false;
      Logger.info(TAG, 'Cooperate manager cleaned up');
    } catch (error) {
      Logger.error(TAG, 'Error cleaning up cooperate manager: ' + JSON.stringify(error));
    }
  }

  /**
   * 选择设备进行键鼠穿越
   */
  private async selectDeviceForCooperate(): Promise<void> {
    try {
      await this.remoteDeviceModel.createDeviceManager();
      const trustedDevices: deviceManager.DeviceBasicInfo[] = this.remoteDeviceModel.trustedDeviceList;
      
      if (trustedDevices.length === 0) {
        constant.showToast('没有可用的设备，请先在设备管理器中连接设备');
        return;
      }

      // 如果只有一个设备，直接选择
      if (trustedDevices.length === 1) {
        this.selectedDeviceForCooperate = trustedDevices[0];
        constant.showToast('已选择设备: ' + trustedDevices[0].deviceName);
        return;
      }

      // 多个设备时，选择第一个作为默认设备（实际应用中可以弹出选择对话框）
      this.selectedDeviceForCooperate = trustedDevices[0];
      constant.showToast('已选择设备: ' + trustedDevices[0].deviceName + ' (默认选择第一个设备)');
      
    } catch (error) {
      Logger.error(TAG, 'Failed to select device: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('选择设备失败: ' + errorMessage);
    }
  }

  /**
   * 开始键鼠穿越
   */
  private async startCooperate(): Promise<void> {
    if (!this.isCooperateInitialized) {
      constant.showToast('键鼠穿越功能尚未初始化，请稍候再试');
      Logger.error(TAG, 'Cooperate manager not initialized');
      return;
    }

    if (this.cooperateStatus !== CooperateStatus.IDLE) {
      constant.showToast('键鼠穿越已在运行中');
      return;
    }

    if (!this.selectedDeviceForCooperate) {
      await this.selectDeviceForCooperate();
      if (!this.selectedDeviceForCooperate) {
        return;
      }
    }

    try {
      this.isCooperateStartClick = true;
      setTimeout(() => {
        this.isCooperateStartClick = false;
      }, 2000);

      const deviceNetworkId = this.selectedDeviceForCooperate.networkId;
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
    if (!this.isCooperateInitialized) {
      constant.showToast('键鼠穿越功能尚未初始化');
      return;
    }

    if (this.cooperateStatus === CooperateStatus.IDLE) {
      constant.showToast('键鼠穿越未运行');
      return;
    }

    try {
      this.isCooperateStopClick = true;
      setTimeout(() => {
        this.isCooperateStopClick = false;
      }, 2000);

      Logger.info(TAG, 'Stopping cooperate...');
      
      // 停止追踪鼠标位置
      if (this.selectedDeviceForCooperate && this.selectedDeviceForCooperate.networkId) {
        const deviceNetworkId = this.selectedDeviceForCooperate.networkId;
        cooperateManager.stopTrackingMouseLocation(deviceNetworkId);
      }
      
      await cooperateManager.stopCooperate(false);
      constant.showToast('键鼠穿越已停止');
    } catch (error) {
      Logger.error(TAG, 'Failed to stop cooperate: ' + JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : String(error);
      constant.showToast('键鼠穿越停止失败: ' + errorMessage);
    }
  }

  /**
   * 获取键鼠穿越状态文本
   */
  private getCooperateStatusText(): string {
    switch (this.cooperateStatus) {
      case CooperateStatus.IDLE:
        return '未连接';
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

  /**
   * 获取键鼠穿越状态颜色
   */
  private getCooperateStatusColor(): Color {
    switch (this.cooperateStatus) {
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

  @Builder
  IndexMenu(){
    Menu() {
      MenuItem({ startIcon: $r("app.media.ic_virtual_screen"), content: $r("app.string.virtual_screen") })
        .onChange((selected: boolean) => {
          if (selected) {
            this.enableVirtualScreen = !this.enableVirtualScreen;
            if (!this.enableVirtualScreen) {
              this.destroyVirtualScreen();
            }
          }
        })
      MenuItem({ startIcon: $r("app.media.ic_device_manger"), endIcon: $r("app.media.ic_arrow_right"),
          content: $r("app.string.device_manager") })
        .onChange((selected: boolean) => {
          if (selected) {
            this.routeDeviceManagerPage();
          }
        })
      MenuItem({ startIcon: "🖱️", endIcon: $r("app.media.ic_arrow_right"), content: "键鼠穿越测试" })
        .onChange((selected: boolean) => {
          if (selected) {
            this.routeCooperateTestPage();
          }
        })
    }
  }

  build() {
    Column() {
      Row() {
          Row() {
            Image($r('app.media.ic_more'))
              .padding(4)
              .width(40)
              .objectFit(ImageFit.Contain)
          }
          .alignItems(VerticalAlign.Center)
          .borderRadius(5)
          .width(60)
          .height(60)
          .backgroundColor($r('app.color.background_light_gray'))
          .bindMenu(this.IndexMenu)
      }
      .justifyContent(FlexAlign.End)
      .margin({ top: 6 })
      .width('100%')

      Column() {
        // 屏幕镜像状态
        Text(this.isStarted ? $r('app.string.screen_mirroring') : $r('app.string.str_null'))
          .fontSize("24px")
          .fontColor('0xff0000')
          .margin({ top: 6})
        
        // 键鼠穿越状态
        Row() {
          Text('键鼠穿越: ')
            .fontSize("20px")
            .fontColor(Color.Black)
          Text(this.isCooperateInitialized ? this.getCooperateStatusText() : '初始化中...')
            .fontSize("20px")
            .fontColor(this.isCooperateInitialized ? this.getCooperateStatusColor() : Color.Orange)
        }
        .margin({ top: 4 })
        
        // 选中的设备信息
        if (this.selectedDeviceForCooperate) {
          Text(`目标设备: ${this.selectedDeviceForCooperate.deviceName}`)
            .fontSize("16px")
            .fontColor(Color.Blue)
            .margin({ top: 2 })
        }
      }
      .width('100%')

      Scroll() {
        Column() {
          if (this.enableVirtualScreen) {
            XComponent({ id: 'xcomponent', type: 'surface', controller: this.xcomponentController })
              .onLoad(() => {
                this.xcomponentController!.setXComponentSurfaceSize(
                  { surfaceWidth: this.virtualScreenWidth, surfaceHeight: this.virtualScreenHeight });
                this.createVirtualScreen(this.xcomponentController!.getXComponentSurfaceId());
              })
              .width('75%')
              .height('75%')
              .backgroundColor(Color.White)
          }

          if (this.isLandscape) {
            Column() {
              // 屏幕镜像按钮行
              Row() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.mirror'))
                      .padding(4)
                      .width(120)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_start')).fontSize("80px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStartClick ? Color.Green : Color.Blue)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('42%')
                .height('60%')
                .onClick(() => {
                  this.switchMirrorFunction();
                })

                Blank().width("20px")

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.ic_stop'))
                      .padding(4)
                      .width(120)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_stop')).fontSize("80px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStopClick ? Color.Red : Color.Blue)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('42%')
                .height('60%')
                .onClick(() => {
                  this.isStopClick = true;
                  setTimeout(() => {
                    this.isStopClick = false;
                  }, 2000);

                  if (this.isStarted) {
                    this.isStarted = false;
                    this.makeMirrorStop();
                  } else {
                    constant.showToast(this.notStarted);
                  }
                })
              }
              .height('40%')
              
              // 键鼠穿越按钮行
              Row() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Text('🖱️').fontSize("60px").margin({ right: 8 })
                    Text('开始键鼠穿越').fontSize("80px").fontColor(0xffffff)
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isCooperateStartClick ? Color.Green : Color.Orange)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('42%')
                .height('60%')
                .enabled(this.isCooperateInitialized && this.cooperateStatus === CooperateStatus.IDLE)
                .onClick(() => {
                  this.startCooperate();
                })

                Blank().width("20px")

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Text('⏹️').fontSize("60px").margin({ right: 8 })
                    Text('停止键鼠穿越').fontSize("80px").fontColor(0xffffff)
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isCooperateStopClick ? Color.Red : Color.Orange)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('42%')
                .height('60%')
                .enabled(this.isCooperateInitialized && this.cooperateStatus === CooperateStatus.ACTIVE)
                .onClick(() => {
                  this.stopCooperate();
                })
              }
              .height('40%')
              
              // 设备选择按钮
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text('选择设备').fontSize("60px").fontColor(0xffffff)
              }
              .backgroundColor(Color.Gray)
              .margin({ top: 20 })
              .borderRadius(20)
              .width('60%')
              .height('20%')
              .onClick(() => {
                this.selectDeviceForCooperate();
              })
            }
            .height('100%')
            .width('100%')
          } else {
            Column() {
              Column() {
                // 屏幕镜像按钮
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.mirror'))
                      .padding(4)
                      .width(60)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_start')).fontSize("40px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStartClick ? Color.Green : Color.Blue)
                .margin({ top: 14 })
                .borderRadius(20)
                .width('80%')
                .height('15%')
                .onClick(() => {
                  this.switchMirrorFunction();
                })

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.ic_stop'))
                      .padding(4)
                      .width(60)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_stop')).fontSize("40px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStopClick ? Color.Red : Color.Blue)
                .margin({ top: 14 })
                .borderRadius(20)
                .width('80%')
                .height('15%')
                .onClick(() => {
                  this.isStopClick = true;
                  setTimeout(() => {
                    this.isStopClick = false;
                  }, 2000);

                  if (this.isStarted) {
                    this.isStarted = false;
                    this.makeMirrorStop();
                  } else {
                    constant.showToast(this.notStarted);
                  }
                })

                // 键鼠穿越按钮
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Text('🖱️').fontSize("30px").margin({ right: 6 })
                    Text('开始键鼠穿越').fontSize("40px").fontColor(0xffffff)
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isCooperateStartClick ? Color.Green : Color.Orange)
                .margin({ top: 14 })
                .borderRadius(20)
                .width('80%')
                .height('15%')
                .enabled(this.isCooperateInitialized && this.cooperateStatus === CooperateStatus.IDLE)
                .onClick(() => {
                  this.startCooperate();
                })

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Text('⏹️').fontSize("30px").margin({ right: 6 })
                    Text('停止键鼠穿越').fontSize("40px").fontColor(0xffffff)
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isCooperateStopClick ? Color.Red : Color.Orange)
                .margin({ top: 14 })
                .borderRadius(20)
                .width('80%')
                .height('15%')
                .enabled(this.isCooperateInitialized && this.cooperateStatus === CooperateStatus.ACTIVE)
                .onClick(() => {
                  this.stopCooperate();
                })

                // 设备选择按钮
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Text('选择设备').fontSize("40px").fontColor(0xffffff)
                }
                .backgroundColor(Color.Gray)
                .margin({ top: 14 })
                .borderRadius(20)
                .width('80%')
                .height('15%')
                .onClick(() => {
                  this.selectDeviceForCooperate();
                })
              }
            }
            .height('100%')
            .width('100%')
          }
        }
        .height('100%')
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
    }
    .height('100%')
    .backgroundColor($r('app.color.background_light_gray'))
  }
}