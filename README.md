# MTLauncher

> **Fork 说明:** 本项目 fork 自 [FLauncher](https://gitlab.com/flauncher/flauncher) —— 一个用 [Flutter](https://flutter.dev) 编写的开源 Android TV 第三方启动器。本 fork 维护于 [urbanescavenger/MTLauncher](https://github.com/urbanescavenger/MTLauncher),并更名为 **MTLauncher**。本 fork 相对原版的完整改动见 [CHANGELOG](CHANGELOG.md)。
>
> English version: [README.en.md](README.en.md)

MTLauncher 是一个基于分类的 Android TV 启动器:应用按自定义分类分组,以横向列表或网格浏览,主页底部固定一条收藏栏。

## 下载

- **稳定版**:从 [releases](https://github.com/urbanescavenger/MTLauncher/releases) 页面获取最新 APK。稳定版由 `v*` tag 触发构建(如 `v1.0.0`);带后缀的 tag(如 `v1.0.0-alpha.1`)为预发布版。
- **开发版**:每次推送到 `debug` 分支都会触发 CI 构建,并发布到固定的 [`debug` tag release](https://github.com/urbanescavenger/MTLauncher/releases/download/debug/MTlauncher-debug.apk),覆盖上一次构建。开发版可能不稳定。

应用内置**检查更新**(设置 → 检查更新),会解析最新 release 并对比版本,因此可以直接在启动器内升级安装。

## 功能

本 fork 新增:

- [x] 三页式启动器:主页、分类页、全部应用页
- [x] 主页底部固定收藏栏,收藏栏名称跟随应用内语言
- [x] 每个分区末尾都有"添加应用"卡片,空分区也以它作为占位
- [x] 应用内语言切换(English / Español / 中文)
- [x] 应用内检查更新(含版本号对比),正式版与开发版均支持
- [x] FocusGuard:焦点丢失后自动恢复 D-pad 焦点(启动、回前台、页面切换)
- [x] 翻页时自动跳过空的分类页

继承自上游 FLauncher:

- [x] 无广告
- [x] 自定义分类
- [x] 分类内手动排序应用
- [x] 壁纸支持
- [x] 打开"系统设置" / "应用信息"
- [x] 卸载应用
- [x] 时钟及可自定义的日期组件格式
- [x] 分类可在横向列表和网格之间切换
- [x] 支持非 TV(侧载)应用
- [x] 导航按键音效(可关闭)
- [x] 返回键行为可选:无操作 / 全屏时钟 / 屏保(Ambient Mode)
- [ ] 强制停止应用

相对原版 FLauncher 的累计改动见 [CHANGELOG.md](CHANGELOG.md)。

## 截图

|  |  |  |
|--|--|--|
| ![](screenshots/Screenshot_1624378896.png) | ![](screenshots/Screenshot_1624378921.png) | ![](screenshots/Screenshot_1624378938.png) |

## 设为默认启动器

### 方法一:重映射 Home 键
这是更"安全"也最简单的方式。用 [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) 把遥控器的 Home 键重映射为打开 MTLauncher。

### 方法二:禁用系统默认启动器
**:warning: 免责声明 :warning:**

**操作风险自负,因操作导致设备出现任何问题由你自己负责。**

以下命令仅在 Chromecast with Google TV 上测试过,其他设备可能有所不同。

禁用默认启动器后,按遥控器的 Home 键,系统会弹出选择框让你指定默认启动器,此时选择 MTLauncher 即可。

#### 禁用默认启动器
```shell
# 禁用 com.google.android.apps.tv.launcherx,这是 CCwGTV 上的默认启动器
$ adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
# com.google.android.tungsten.setupwraith 会作为"后备"启动器自动重新启用默认启动器,所以也要禁用
$ adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
```

#### 重新启用默认启动器
```shell
$ adb shell pm enable com.google.android.apps.tv.launcherx
$ adb shell pm enable com.google.android.tungsten.setupwraith
```

#### 已知问题
在 Chromecast with Google TV(可能还有其他设备)上,禁用默认启动器后遥控器的"YouTube"按键会失效。解决办法同样是用 [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) 重映射该按键。

## 壁纸
由于部分 Android TV 设备没有 `WallpaperManager`,MTLauncher 实现了自己的壁纸管理方式。

注意:更换壁纸需要设备上已安装文件管理器,用于挑选壁纸文件。

## 构建
主要分发渠道是 CI 云构建(GitHub Actions,Flutter 3.24.5 + Java 17),本地也可以用标准 Flutter 环境构建:

```shell
flutter pub get
flutter build apk --release
```

## 致谢与许可

- 原版 FLauncher 作者 [etienn01](https://github.com/etienn01)([GitLab](https://gitlab.com/flauncher/flauncher)),欢迎[支持原作者](https://www.buymeacoffee.com/etienn01)。
- <a href="https://www.buymeacoffee.com/etienn01" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="200"></a>
- 本项目沿用原版的 [GPL-3.0](LICENSE) 许可证。