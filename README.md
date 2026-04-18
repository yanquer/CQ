# CQ

CQ 是一个 macOS 菜单栏工具，用来拦截误触的 `Cmd + Q`。

默认情况下，按下一次 `Cmd + Q` 不会立刻退出应用；只有在设定时间内再次触发，才会真正退出。这样可以在日常工作里减少误关应用的情况。

## 功能

- 拦截单次 `Cmd + Q`
- 支持双击确认退出
- 支持登录时启动
- 支持白名单应用跳过二次确认
- 支持在菜单栏面板内直接调整常用设置

## 使用方式

1. 启动应用后，图标会常驻在菜单栏。
2. 点击菜单栏图标，打开设置面板。
3. 根据需要调整退出确认时间、提示停留时间或白名单应用。
4. 一般保持默认设置即可。

## mac mini / 多设备排查

当某台设备出现“`CQ` 进程还在，但 `Cmd + Q` 不再被拦截”时，请优先按下面顺序排查：

1. 先确认应用进程仍在运行：
   `pgrep -fal CQ`
2. 再确认权限状态：
   辅助功能、输入监控 / 事件监听都需要已授权。
3. 如果权限看起来正常，再检查诊断文件：
   `~/Library/Application Support/CQ/quit-guard-diagnostics.json`
4. 最后再检查应用签名与环境状态：
   `codesign --verify --deep --strict /Applications/CQ.app`

诊断文件会记录：

- 当前进程 `pid`
- 当前应用路径与 bundle id
- 权限快照
- tap 创建策略、尝试结果与最近失败原因
- 代码签名状态
- 声明的 sandbox 状态
- 推断出的主要失败原因

如果诊断文件里已经提示权限满足，但 `suspectedFailureReason` 仍然是 `invalidCodeSignature`、`tapCreateReturnedNil` 或 `declaredSandboxButUnavailable`，请先重启应用，再重新验证一次。

## 开发说明

- 本地跑单测时建议关闭签名校验，避免被已撤销证书影响：
  `xcodebuild test -project CQ.xcodeproj -scheme CQ -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' -only-testing:CQTests`
- 如果要定位退出保护问题，优先查看统一日志和上面的诊断文件，两边会输出同一套事件名：
  `launch_sync`、`wake_sync`、`permission_refresh`、`tap_create_attempt`、`tap_create_result`、`tap_disabled`、`tap_recovery_result`、`environment_diagnosed`

## 界面预览

<table>
  <tr>
    <td align="center" width="50%">
      <img src="resources/images/new_cq.png" alt="CQ 菜单栏界面" width="100%" />
      <br />
      <sub>菜单栏界面</sub>
    </td>
    <td align="center" width="50%">
      <img src="resources/images/new_cq_tip.png" alt="CQ 触发弹窗" width="100%" />
      <br />
      <sub>触发弹窗</sub>
    </td>
  </tr>
</table>
