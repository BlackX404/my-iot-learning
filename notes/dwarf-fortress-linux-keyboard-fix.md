# 矮人要塞 Linux 版键盘失灵修复

## 问题

运行矮人要塞 (Dwarf Fortress) Linux 经典版 (`games/df_linux/run_df`) 后，游戏内大部分键盘按键无响应（如 `w` `a` `s` `d` 方向键、空格、`k` 等），只有 ESC、F11 等功能键可用，只能用鼠标操作。正常情况下矮人要塞应以键盘操作为主。

## 环境

- OS: Ubuntu 24.04 (Noble)
- DF 版本: 经典版 (Classic ASCII), SDL2
- SDL2: 系统安装版 `libsdl2-2.0-0 2.30.0`
- 输入法: ibus-daemon + ibus-engine-libpinyin (中文拼音)

## 根因

ibus 输入法框架在激活状态下会拦截键盘事件用于中文输入组合 (preedit/composition)。SDL2 应用接收到的不是原始按键，而是被 ibus 处理后的输入。ESC、F11 等功能键不参与输入法组合流程，所以不受影响 —— 恰好符合「只有 ESC 等可用」的症状。

诊断命令：

```sh
# 确认 ibus 进程
ps aux | grep -i ibus

# 确认环境变量
env | grep -iE "(ibus|im_module|xmodifiers)"

# 确认 SDL2 来自系统而非 DF 自带
ldd dwarfort | grep sdl
```

## 解决方案

修改 `games/df_linux/run_df`，在启动 dwarfort 前清除输入法相关环境变量：

```diff
 #!/bin/sh
 DF_DIR=$(dirname "$0")
 cd "${DF_DIR}"
+
+# 禁用输入法以避免键盘捕获问题 (ibus/fcitx 会拦截 SDL2 按键)
+unset GTK_IM_MODULE
+unset QT_IM_MODULE
+export XMODIFIERS=@im=none
+
 LD_LIBRARY_PATH="..." ./dwarfort "$@"
```

三行说明：

| 设置 | 作用 |
|------|------|
| `unset GTK_IM_MODULE` | 清除 GTK 输入法模块绑定 |
| `unset QT_IM_MODULE` | 清除 Qt 输入法模块绑定 |
| `XMODIFIERS=@im=none` | 禁用 XIM 输入法协议，阻止 ibus 拦截键盘 |

这些环境变量只对 `dwarfort` 进程及其子进程生效，不影响系统其他应用的中文输入。

## 备选方案（更彻底）

如果上述修改后仍有少数按键不响应，可以在终端中手动关闭 ibus 再启动游戏：

```sh
ibus exit
./games/df_linux/run_df
# 游戏结束后恢复输入法：
ibus-daemon --xim --panel disable &
```

## 参考

- [DF Wiki: Linux troubleshooting](https://dwarffortresswiki.org/index.php/DF2014:Installation#Linux)
- SDL2 输入法处理: `SDL_IM_MODULE` 环境变量
