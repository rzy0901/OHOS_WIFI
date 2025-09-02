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
      }).catch((err: string) => {
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

  aboutToAppear() {
    Logger.info(TAG, 'aboutToAppear')
    let portraitFunc = (mediaQueryResult: mediaquery.MediaQueryResult): void => this.onPortrait(mediaQueryResult)
    this.listener.on('change', portraitFunc);
    this.xcomponentController = new XComponentController();
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
        Text(this.isStarted ? $r('app.string.screen_mirroring') : $r('app.string.str_null'))
          .fontSize("24px")
          .fontColor('0xff0000')
          .margin({ top: 6})
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
              Row() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.mirror'))
                      .padding(4)
                      .width(180)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_start')).fontSize("120px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStartClick ? Color.Green : Color.Blue)
                .margin({ top: 56 })
                .borderRadius(20)
                .width('42%')
                .height('80%')
                .onClick(() => {
                  this.switchMirrorFunction();
                })

                Blank().width("20px")

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.ic_stop'))
                      .padding(4)
                      .width(180)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_stop')).fontSize("120px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStopClick ? Color.Red : Color.Blue)
                .margin({ top: 56 })
                .borderRadius(20)
                .width('42%')
                .height('80%')
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
            }
            .height('100%')
            .width('100%')
          } else {
            Column() {
              Column() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.mirror'))
                      .padding(4)
                      .width(90)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_start')).fontSize("60px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStartClick ? Color.Green : Color.Blue)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('80%')
                .height('40%')
                .onClick(() => {
                  this.switchMirrorFunction();
                })

                Blank().height("10px")

                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    Image($r('app.media.ic_stop'))
                      .padding(4)
                      .width(90)
                      .objectFit(ImageFit.ScaleDown)
                    Text($r('app.string.screen_stop')).fontSize("60px").fontColor(0xffffff).margin({ left: 5, right: 12 })
                  }.alignItems(VerticalAlign.Center)
                }
                .backgroundColor(this.isStopClick ? Color.Red : Color.Blue)
                .margin({ top: 28 })
                .borderRadius(20)
                .width('80%')
                .height('40%')
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