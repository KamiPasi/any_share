# file_manager

速享依赖的 `nightmare-space/file_manager` 是作者的私有仓库，开源代码拉不到它，所以谁都编译不了。
这个包按速享对它的用法重新实现了一遍，接口保持一致，速享本身的代码不用改。

## 提供的接口

| 接口 | 用途 |
| --- | --- |
| `FileManagerView`、`FileManagerPage` | 本地文件浏览：打开、重命名、删除、新建文件夹、常用位置、显示隐藏文件 |
| `FileManager.selectFile()` | 应用内选择文件，可多选、可跨文件夹，取消时返回空列表 |
| `FileManager.selectDirectory()` | 应用内选择文件夹，取消时返回 `null` |
| `Server.routes`、`Server.getFileServerHandler()` | 浏览器远程管理文件的 HTTP 接口，由速享的消息服务转交请求 |
| `Server.start()` | 初始化；不单独监听端口 |
| `Config.package` | 包名，速享用它加载 `assets/icon/dir.svg` |

## HTTP 接口

`/sdcard` 是网页端约定的根路径：安卓上对应内部存储，其他平台对应用户主目录。超出根目录的路径一律拒绝。
速享只在设置里打开“网页服务”后才会把请求转交过来。

| 请求 | 说明 |
| --- | --- |
| `GET /getdir?path=/sdcard/xxx` | 目录内容。返回 JSON 字符串数组，每项是一行 `ls -aog` 格式的文字，和速享自带网页端的解析方式一致 |
| `GET /rename?path=...&name=...` | 重命名 |
| `GET /delete?path=...` | 删除，文件夹连同内容一起删除 |
| `GET /mkdir?path=...&name=...` | 新建文件夹 |
| `POST /upload?path=...&name=...` | 上传，请求体是文件内容，重名时自动改名 |
| `GET /sdcard/...` | 文件夹返回可操作的目录页面；文件直接返回内容，支持 `Range`（断点续传、视频拖动），加 `?download=true` 时作为附件下载 |
