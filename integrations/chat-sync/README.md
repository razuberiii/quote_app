# Rubusoo 聊天同步脚本

第一阶段支持 WhatsApp Web 与 Alibaba 国际站消息中心。脚本只会采集用户已授权网站中、已主动绑定到 Rubusoo 的会话；未绑定会话、输入框草稿、Cookie 与完整网页 HTML 均不会上传。

## 构建

```powershell
npm run build:chat-sync
```

产物为 `public/integrations/rubusoo-chat-sync.user.js`。业务模块位于 `src/core`，平台解析位于 `src/adapters`，GM API 仅封装在 `src/runtime/tampermonkey-runtime.js`，便于后续迁移 Manifest V3。

## 使用

1. 登录 Rubusoo，进入“导入与连接 → 聊天自动同步”。
2. 在 Tampermonkey 或 Violentmonkey 中安装脚本。
3. 在 Rubusoo 生成一次性绑定码。
4. 打开 WhatsApp Web 或 Alibaba 消息中心，在浮窗中授权当前网站并输入绑定码。
5. 打开客户会话，关联现有询盘或创建客户与询盘。
6. 绑定后，当前会话中正常显示或滚动加载的消息会进入本地队列并批量上传。

脚本不会自动无限滚动历史记录。网络失败时消息保存在脚本存储中，并采用指数退避重试。

## 适配器维护

平台 DOM 变化时，只修改对应 `src/adapters/*` 实现。每个适配器必须返回统一消息模型，且不得把 DOM 节点或整段 HTML 放入 `sourceMetadata`。
