# BitsButton 项目 Copilot 指南# BitsButton — Copilot 指南（针对 AI 编码代理）



## 项目概述目的：让 AI 代理在最短时间内理解仓库的“为什么/如何做”，并能安全、可重复地完成常见编辑、构建和测试任务。



BitsButton 是一个嵌入式按钮检测框架，使用位序列编码来追踪按钮状态。该项目实现了一个复杂的有限状态机(FSM)来处理各种按钮交互模式，包括单击、双击、长按等。要点速览

- 核心库：`bits_button.c` / `bits_button.h` — 事件检测与状态机实现（支持单/连/长按/组合）。

## 核心设计理念- 模拟器：`simulator/`（含 `adapter_layer/` 与 `python_simulator/`）用于本地交互和 UI 验证；`adapter_layer/button_adapter.*` 提供与核心库的绑定（见导出函数如 `button_ticks_wrapper`、`set_key_state`）。

- 测试：`test/` 目录使用 Unity + CMake 构建；顶层 `run_tests.bat` 与 `test/scripts/run_tests.bat` 是常用入口。

### 1. 状态机编程思想

架构与数据流（简明）

BitsButton 项目采用了状态机编程模式来跟踪和管理按钮状态。核心状态机在 `update_button_state_machine()` 函数中实现(bits_button.c 617-723行)。- 设备侧的“读键”由用户实现的回调 `bits_btn_read_button_level` 提供，核心通过 `bits_button_ticks()` 周期调用构建状态机。

- 事件发布有两种模式：回调模式（在 `bits_button_init` 传入 `bits_btn_result_cb`）或缓冲区模式（默认，写入统一 `bits_btn_buffer_ops_t` 接口），消费方通过 `bits_button_get_key_result()` 读取。

#### 状态机关键特点：- 缓冲区有三种实现方式（通过编译宏选择）：

  - 默认：C11 原子环形缓冲（`-std=c11`，支持 `_Atomic`）

- **状态定义**：在 `bits_btn_state_t` 枚举中定义了6个基本状态  - 禁用缓冲：`-DBITS_BTN_DISABLE_BUFFER`（极小内存/回调式场景）

  - `BTN_STATE_IDLE`: 空闲状态，等待按钮按下  - 用户缓冲：`-DBITS_BTN_USE_USER_BUFFER`（需要调用 `bits_button_set_buffer_ops()` 注册实现）

  - `BTN_STATE_PRESSED`: 按下状态，检测是否进入长按或释放

  - `BTN_STATE_LONG_PRESS`: 长按状态，处理持续按压关键约定与模式（供代码生成/修改时遵循）

  - `BTN_STATE_RELEASE`: 释放状态，记录释放事件- 初始化签名：`bits_button_init(btns, btns_cnt, btns_combo, btns_combo_cnt, read_fn, result_cb, debug_printf)`。

  - `BTN_STATE_RELEASE_WINDOW`: 释放窗口状态，等待可能的下一次按键  - 返回值含义：`0` 成功，`-1`/`-2`/`-3` 表示配置/参数相关错误（参阅 `bits_button.h` 注释）。

  - `BTN_STATE_FINISH`: 完成状态，触发最终事件并返回空闲- 缓冲区接口：`bits_btn_buffer_ops_t`（必须实现 `init/write/read/is_empty/is_full/get_buffer_used_count/clear/get_buffer_overwrite_count/get_buffer_capacity`），通过 `bits_button_set_buffer_ops()` 注册。

- 组合按键优先级在初始化时按 `key_count` 降序排序（见 `sort_combo_buttons_in_init`），新增 combo 时确保 `key_single_ids` 与 `btns` 中的 `key_id` 对应。

- **状态转换**：基于当前状态、按钮输入和时间条件进行转换- 日志：将调试输出函数以 `bits_btn_debug_printf_func` 形式传入 `bits_button_init`；在自动化/CI 中可传 `NULL`。

  - 使用 `switch-case` 结构处理不同状态下的逻辑

  - 在每个状态内部，通过条件判断确定何时转换到下一个状态常用开发/运行命令（Windows 下的快速步骤）

  - 运行全部测试（快速入口）：`.run_tests.bat`（位于仓库根）或 `test\scripts\run_tests.bat`。

- **位序列编码**：使用位序列记录按钮操作历史- 手动使用 CMake：

  - 通过 `__append_bit()` 函数向状态位添加1或0  - cd test && mkdir build && cd build

  - 使用预定义的位模式识别特定按键组合(如单击、双击、长按)  - `cmake ..` then `cmake --build . --target run_tests_new`

- 切换缓冲区模式的试验编译示例（依据 `run_tests.bat` 中的做法）：

### 2. 缓冲区实现  - `gcc -c -std=c11 bits_button.c`  （默认 C11 原子缓冲）

  - `gcc -c -DBITS_BTN_DISABLE_BUFFER -std=c99 bits_button.c`（无缓冲）

项目提供了三种缓冲区实现模式：  - `gcc -c -DBITS_BTN_USE_USER_BUFFER -std=c99 bits_button.c`（用户缓冲）

- C11 原子操作缓冲区（默认）

- 禁用缓冲区模拟器与本地调试要点

- 用户自定义缓冲区- `simulator/run.py` 能帮助生成并编译一个共享库（`button.dll` / `libbutton.so` / `libbutton.dylib`），`adapter_layer` 包含绑定实现，导出函数供 GUI/脚本调用（`button_ticks_wrapper`、`set_key_state`、`get_button_key_value_wrapper`）。

- 若需要 UI 或系统键监听（macOS 有权限问题），`simulator/run.py` 中包含检查和自动修复建议；agent 在修改该脚本时应保持平台分支与权限提示逻辑。

这些模式可以在编译时选择，适应不同的系统需求和约束。

测试与 CI 约定

### 3. 组合按键支持- 测试使用 Unity（`test/Unity/src/unity.c`）并由 `CMakeLists.txt` 收集源文件生成 `run_tests_new`。

- CI 会在多平台（Ubuntu/Windows/macOS）上验证：

项目支持组合按键检测，允许多个按键同时按下时触发特定事件。这通过位掩码和抑制机制实现。  - 是否能在三种缓冲区模式下编译（见 `run_tests.bat` 的多编译校验）

  - 是否通过全部测试套（labels: `new_architecture;full_test`）

## 代码约定

修改/新增代码的注意事项（AI 应遵守）

1. 函数命名采用下划线分隔的小写字母- 修改核心状态机或计时常量时：同步更新 `bits_button.h` 中的宏（如 `BITS_BTN_TICKS_INTERVAL`、`BITS_BTN_DEBOUNCE_TIME_MS`）并在 `test/config/test_config.h` 中保持测试参数一致。

2. 常量使用大写字母和下划线- 若修改缓冲区实现，请保证 `bits_btn_buffer_ops_t` 接口兼容性，并在 `test/` 中新增 buffer 边界/并发相关用例。

3. 变量名采用驼峰命名法或下划线分隔- 新增导出给模拟器的函数时，更新 `simulator/adapter_layer/button_adapter.h` 的导出声明（`BUTTON_API`）以保持跨平台可见性。

4. 使用typedef定义类型别名以增强可读性

示例片段（快速参考）

## 主要工作流- 注册用户缓冲：`bits_button_set_buffer_ops(&my_buffer_ops);` 然后 `bits_button_init(...)`。

- 读取事件（轮询模式）：

1. **初始化按钮**：使用 `bits_btn_init` 或预定义的宏  - `bits_btn_result_t r; while (bits_button_get_key_result(&r)) { /* 处理 */ }`

2. **周期性调用**：通过 `bits_btn_scan` 定期更新按钮状态

3. **事件处理**：通过回调函数或轮询缓冲区处理按钮事件什么时候需要询问人类：

- 对底层硬件 GPIO/中断交互逻辑的改动（适配层）或在 CI 编译链中新增系统依赖（例如新增外部 C 库）。

## 常见模式- 涉及安全/权限（macOS Accessibility）或需要运行本地 GUI 的改动时，请先征询开发者。



1. **位模式匹配**：使用预定义位模式识别特定按键序列文件引用（首要阅读顺序）

   - 例如：`0b010` 表示单击，`0b01010` 表示双击- `bits_button.h`, `bits_button.c` — 必读；理解状态机与 buffer 模式。

- `simulator/adapter_layer/button_adapter.c`、`button_adapter.h` — 模拟器集成点。

2. **时间窗口**：使用时间窗口来区分不同类型的按键操作- `test/CMakeLists.txt`, `test/scripts/run_tests.bat`、`run_tests.bat` — 构建/测试与 CI 校验流程。

   - 例如：长按检测、连击检测等- `test/` 下的 `cases/` 与 `utils/` — 如何编写和断言测试用例的范例。



## 关键文件如果有不清楚的地方，请指出具体目标（例如“新增 combo 支持到 5 键”或“在默认缓冲上添加额外的事件过滤”），我会基于对应文件做精确修改并运行测试验证。


- `bits_button.h`：公共API和主要类型定义
- `bits_button.c`：状态机实现和核心逻辑
- `/test`：使用Unity框架的测试用例

## 注意事项

1. 状态机的正确操作依赖于定期调用 `bits_btn_scan` 函数
2. 按钮配置参数影响状态机的转换条件和时间
3. 缓冲区模式的选择应根据目标平台的能力和需求确定