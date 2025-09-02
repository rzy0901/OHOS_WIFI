/*
 * Copyright (c) 2023 AlgoIdeas <yu19881234@163.com>
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <iostream>

#include "display.h"
#include "display_manager.h"
#include "dscreen_source_handler.h"
#include "dscreen_sink_handler.h"
#include "dscreen_util.h"
#include "idistributed_hardware_sink.h"
#include "idistributed_hardware_source.h"
#include "screen.h"
#include "screen_client.h"
#include "screen_client_common.h"
#include "screen_manager.h"
#include "wm_common.h"
#include "window.h"
#include "window_option.h"
#include "nativetoken_kit.h"
#include "token_setproc.h"

#include "softbus_adapter_mem.h"
#include "softbus_bus_center.h"
#include "softbus_common.h"

using namespace std;
using namespace OHOS;
using namespace OHOS::DistributedHardware;
using namespace OHOS::Rosen;
using namespace OHOS::Media;

int main(int argc, char **argv)
{
    uint64_t remoteScreenId;
    std::string remoteScreenName;

    // 获取 screen列表
    std::vector<sptr<Screen>> allScreens = ScreenManager::GetInstance().GetAllScreens();

    // 选择待镜像的远程目标 screen
    // IsReal 返回true时 代表为本地screen / false为远程screen
    // GetName 当返回screen的id 包含远程设备信息
    // GetId 返回screenId
    for (auto screen: allScreens) {
        if (!screen->IsReal()) {
          // 仅找第一个远程screen
          remoteScreenId = screen->GetId();
          remoteScreenName = screen->GetName();
          break;
        }
    }

    printf("[DscreenExpand] remoteScreenId : %lu.\n", remoteScreenId);
    printf("[DscreenExpand] remoteScreenName : %s.\n", remoteScreenName.c_str());

    // 选择待拓展的本地screen
    sptr<OHOS::Rosen::Display> defaultDisplay = OHOS::Rosen::DisplayManager::GetInstance().GetDefaultDisplay();
    uint64_t localScreenId = defaultDisplay->GetScreenId();

    printf("[DscreenExpand] localScreenId : %lu...\n", localScreenId);

    // 拓展屏幕与本地屏幕的位置关系
    std::vector<ExpandOption> options = {
        {localScreenId, 0, 0},
        {remoteScreenId, defaultDisplay->GetWidth(), 0}
    };

    // 调用结构启动拓展投屏
    ScreenManager::GetInstance().MakeExpand(options);

    printf("[DscreenExpand] Wait MakeExpand Stop.\n");
    getchar();

    // 停止投屏
    std::vector<uint64_t> stopExpandIds;
    stopExpandIds.push_back(remoteScreenId);
    ScreenManager::GetInstance().RemoveVirtualScreenFromGroup(stopExpandIds);

    return 0;
}