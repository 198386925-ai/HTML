# LUIYo 后台（iOS 管理端）

与网页版 `admin.php` 功能完全一致的原生 iOS 管理 App。

- **总览**：统计总览（4项）+ 设备与在线用户（3项）+ 快捷导航
- **生成**：生成激活码（备注/数量/设备数/天数）+ 近期生成记录（批量复制，保存在本机）
- **设备**：设备码授权（授权 SVIP / 撤销）+ 设备列表（筛选/搜索/封禁/解封）
- **卡密**：激活码列表（搜索/停用/启用/删除）
- **版本**：登记/禁用版本 + 已登记版本（解禁/删除）

## 后端

对接 `api-native.php`（session 会话鉴权），默认服务器
`https://mistoto.cc.cd/luiyo`，可在登录页和设置里修改。
管理员密码可记住（存 Keychain）。

## 构建

GitHub Actions（macos-15-intel + Xcode 26）：
`scripts/build-ipa.sh` 编译未签名 IPA，产物命名
`LUIYoAdmin-1.0.0-Build(n).ipa`，并附干净源码备份 zip。

注意：`.github/workflows/` 需由仓库管理员在网页端添加
（GitHub App 无 workflows 权限）。
