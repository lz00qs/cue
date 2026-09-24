# 为 Cue 贡献代码

[English](CONTRIBUTING.md) | 简体中文

首先，非常感谢你有兴趣为 Cue 贡献代码！正是因为有你的参与，开源社区才能不断繁荣。

## 如何参与贡献

### 1. 动手前先沟通
如果你打算进行重大修改或添加新功能，请务必**先提出一个 Issue** 来进行讨论。这样可以确保你的工作方向与项目计划一致，避免浪费你的宝贵时间。

### 2. Fork 与分支
1. Fork 本仓库。
2. 创建你的特性分支：`git checkout -b feature/my-new-feature` 或者修复分支 `git checkout -b fix/my-bugfix`。

### 3. 开发规范

**前端 (Flutter)：**
- 确保你的代码遵循标准的 Dart 格式化规范 (`dart format`)。
- 修复所有的静态分析警告：`flutter analyze`。
- 尽可能添加或更新测试，并确保测试通过：`flutter test`。

**后端 (NestJS)：**
- 遵循现有的 ESLint 和 Prettier 配置。
- 对于新加的功能，请添加或更新相关测试。
- 确保集成测试通过：
  ```bash
  # 请确保测试数据库容器已启动
  node --test test/api.integration.test.mjs
  ```

### 4. 提交规范 (Commit)
本项目使用 [约定式提交 (Conventional Commits)](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。请在提交代码时遵循该格式（例如：`feat: 增加超酷的新功能`，`fix: 修复登录页面的 bug`，`docs: 更新 README`）。

### 5. 提交 Pull Request (PR)
- 推送到你的分支：`git push origin feature/my-new-feature`。
- 向本仓库的 `main` 分支发起 Pull Request。
- 在 PR 描述中清晰地说明你的改动。如果你的 PR 修复了某个 Issue，请使用 `Closes #编号` 进行关联。

## 提交 Bug 或需求反馈
如果你发现了 Bug 或者是对 Cue 有优化建议，请直接使用 GitHub 的 Issue 追踪器。在提交前，请先搜索一下是否已经有类似的 Issue，以避免重复提交。

*注意：如果你发现的是安全漏洞，请不要提公开的 Issue，请参考我们的 [安全策略 (SECURITY.md)](SECURITY.zh.md) 私下与我们联系。*
