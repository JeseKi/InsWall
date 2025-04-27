// 话题频道连接
import consumer from "./consumer"

// 这个函数会在用户访问话题页面时被调用
const connectToTopicChannel = (topicName) => {
  console.log(`连接到话题频道: ${topicName}`)
  
  return consumer.subscriptions.create(
    { channel: "TopicChannel", topic: topicName },
    {
      connected() {
        // 连接建立时调用
        console.log(`已连接到话题 #${topicName} 的频道`)
      },

      disconnected() {
        // 连接断开时调用
        console.log(`已断开话题 #${topicName} 的频道连接`)
      },

      received(data) {
        // 收到数据时调用
        console.log(`收到话题 #${topicName} 的新帖子`)
        
        // 获取帖子容器
        const postsContainer = document.getElementById('posts-container')
        
        // 创建临时容器来解析HTML
        const tempDiv = document.createElement('div')
        tempDiv.innerHTML = data.html
        const newPostElement = tempDiv.firstElementChild
        
        // 添加一个动画类
        newPostElement.classList.add('new-post-animation')
        
        // 将新帖子添加到容器的开头
        postsContainer.insertBefore(newPostElement, postsContainer.firstChild)
        
        // 播放动画
        setTimeout(() => {
          newPostElement.classList.remove('new-post-animation')
        }, 1000)
      }
    }
  )
}

export default connectToTopicChannel
