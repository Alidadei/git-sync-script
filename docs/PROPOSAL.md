# Git Auto Sync 简化提案

## 1. 问题

当前脚本使用 `git pull --rebase --autostash`。一旦遇到冲突，仓库可能停留在 rebase 中间态，后续自动同步会持续失败。

本提案的目标不是扩展复杂能力，而是先把当前分支的自动同步做成"失败可安全退出"。

## 2. 设计原则

- 只处理当前分支，不自动切换分支。
- 遇到任何 pull/rebase 冲突，一律 `abort + notify`。
- 多分支支持只通过显式白名单控制，不支持 glob。
- 本阶段不做自动解冲突。
- 本阶段不引入复杂的 merge/rebase 策略切换。

## 3. 最小配置

每个仓库可选提供 `.git-sync.json`：

```json
{
  "branches": ["main", "dev"],
  "notify_on_conflict": true
}
```

字段说明：

| Field | Description |
|-------|-------------|
| `branches` | 可选。显式白名单。只有当前分支在列表中时才执行同步 |
| `notify_on_conflict` | 可选。冲突时是否发送额外通知；日志记录始终保留 |

说明：

- 不支持 `feature-*` 这类模式匹配。
- 不遍历白名单中的所有分支；每次运行只判断"当前分支是否允许同步"。

## 4. 同步流程

### Phase 1: 当前分支检查

1. 获取当前分支名
2. 如果配置了 `branches` 且当前分支不在白名单中：
   - 记录 `SKIP`
   - 结束当前仓库处理

### Phase 2: 保持现有提交流程

1. `git add -A`
2. 若有变更，自动提交
3. 若无变更，继续后续同步

### Phase 3: 拉取与冲突处理

1. 执行 `git pull --rebase --autostash`
2. 若成功，继续执行 `git push`
3. 若失败：
   - 若处于 rebase 状态，执行 `git rebase --abort`
   - 记录日志
   - 发送通知
   - 跳过当前仓库后续 push

伪代码：

```text
detect current branch
if whitelist exists and current branch not allowed:
    log skip
    return

git add -A
if staged changes exist:
    git commit

git pull --rebase --autostash
if pull failed:
    git rebase --abort (if rebase in progress)
    log conflict
    notify user
    return

git push
```

## 5. 冲突处理约定

冲突处理规则只有一条：

```text
冲突 = abort + notify
```

明确不做以下事情：

- 不自动解冲突
- 不做 `--ours` / `--theirs` 自动选择
- 不保留半完成状态给下一次自动任务继续执行
- 不自动 checkout 到其他分支处理

用户收到通知后，手动进入仓库解决冲突。

## 6. 通知

通知分两层：

1. 必须有日志记录
2. 可以补充系统通知

建议：

- Windows：Toast 通知或日志回退
- Linux / macOS：桌面通知或日志回退

如果系统通知不可用，至少保证日志里明确写出：
- 仓库路径
- 当前分支
- pull/rebase 失败
- 已执行 abort

## 7. 优先级

1. 最高优先级：当前分支在冲突时可以安全退出，不把仓库留在异常状态
2. 第二优先级：日志和通知，确保用户知道哪个仓库需要手动处理
3. 第三优先级：`.git-sync.json` 和显式 `branches` 白名单
4. 延后项：自动解冲突、glob 匹配、自动切换/遍历多个分支、复杂策略选择

## 8. 实施阶段

### Phase A: 冲突安全退出（MVP）

- 检测 `git pull --rebase --autostash` 失败
- 检测 rebase 状态
- 执行 `git rebase --abort`
- 写日志
- 跳过 push

### Phase B: 通知

- 增加系统通知
- 无法通知时回退到日志

### Phase C: 分支白名单

- 读取 `.git-sync.json`
- 用 `branches` 显式列表判断当前分支是否允许同步

## 9. 非目标

以下内容不在本提案范围内：

- 自动解冲突
- `feature-*` 之类的 glob 分支匹配
- 自动 checkout / 切换多个分支
- 多分支轮询同步
- merge / rebase 的复杂策略选择
