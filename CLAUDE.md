# 私人饮食助理 — Claude 工作指南

## Environment Notes

- 用户在 **Windows + 中国网络环境**下开发
- 禁止使用 Google 托管的依赖（如 `google_fonts`），会因网络限制加载失败
- 提供下载链接时确保链接有效，且指向正确平台（Windows）
- 所有外部 API 调用假设可能走代理或 compatible-mode 端点，不能假设直连

## Database & Backend

- 项目使用 **FastAPI + SQLite + SQLAlchemy**（无 Alembic 迁移，用 `init_db()` 建表）
- 修改 `backend/models.py` 中的 ORM 模型前，先确认字段变更不会导致已有数据库崩溃
- 新增字段必须有默认值，否则旧数据库启动会报错
- 修改模型后，验证后端能正常启动（无 import 错误）再继续

## API Integration

- 所有 AI API 调用使用 **httpx**（原始 HTTP），不使用官方 SDK
- base_url 必须可配置，从用户设置读取，**不能硬编码**
- 图片生成（通义万象）必须用 DashScope 原生 API（`https://dashscope.aliyuncs.com`），不能用 compatible-mode 地址
- 遇到限流（429）时加间隔重试，不要并发超过 QPS 限制

## Code Quality Checks

- 多文件改动后，确认后端能启动、无 import 错误，再进行下一个功能
- Flutter 中 JSON 响应必须显式 cast（`Map<String, dynamic>.from(e)`），不能直接用
- **不要覆盖已有的 model 文件**，只做增量修改（merge，不是 overwrite）
- 修改 `backend/models.py` 时只添加/修改目标字段，保留其他所有内容
