# InsWall - Instagram 话题墙

InsWall 是一个展示 Instagram 风格帖子的话题墙应用，支持实时更新、灯箱查看和无限滚动加载等功能。

## 功能特点

- **话题分类**：按不同话题展示相关帖子
- **实时更新**：通过 WebSocket 实时接收并显示新帖子
- **新帖通知**：当用户未查看页面顶部时，显示新帖子通知
- **灯箱查看**：点击图片或视频可以在灯箱中全屏查看
- **无限滚动**：自动加载更多内容，无需手动翻页
- **响应式设计**：适配不同设备屏幕大小

## 技术栈

- Ruby on Rails 8.0.2
- WebSocket (Action Cable)
- Plyr.js - 增强视频播放体验
- GLightbox - 提供灯箱功能
- Docker - 容器化部署

## 数据说明

由于暂未获取 Instagram API 授权，项目采用 Mock 数据的方式进行展示。

### 获取 Mock 数据

Mock 数据可以在百度网盘获取：
- 链接: https://pan.baidu.com/s/1hRUppRIDvYzpMcxHuPqnrA?pwd=jese 
- 提取码: jese

下载后直接解压在项目根目录下即可，解压密码为 `password-for-jese`。

## 安装与部署

### 本地开发环境

1. 克隆仓库
   ```bash
   git clone https://github.com/JeseKi/InsWall.git
   cd InsWall
   ```

2. 安装依赖
   ```bash
   bundle install
   ```

3. 下载并解压 Mock 数据到项目根目录

4. 启动开发服务器
   ```bash
   bin/dev
   ```

5. 访问 http://localhost:3000 查看应用

### Docker 部署

使用 Docker Compose 可以快速部署应用：

```bash
docker-compose -f docker-compose.yml -f docker-compose.test.yml up --build -d
```

## 使用说明

1. 打开应用后，可以在顶部选择不同的话题查看相关帖子
2. 点击图片或视频可以在灯箱中全屏查看
3. 滚动页面底部会自动加载更多内容
4. 当有新帖子时，如果您不在页面顶部，会显示通知提醒