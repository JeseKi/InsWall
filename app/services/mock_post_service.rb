class MockPostService
  # 单例模式，确保只有一个实例在运行
  include Singleton
  
  def initialize
    @running = false
    @posts = []
    @topics = []
    @posts_by_topic = {}
    @mutex = Mutex.new  # 线程安全锁
    load_mock_data
  end
  
  # 加载 Mock 数据
  def load_mock_data
    # 读取 JSON 文件
    json_data = File.read(Rails.root.join('data', 'mock_data.json'))
    @posts = JSON.parse(json_data)
    
    # 提取所有唯一的话题
    @topics = @posts.map { |post| post['topic'] }.uniq.sort
    
    # 按话题分组帖子
    @topics.each do |topic|
      @posts_by_topic[topic] = @posts.select { |post| post['topic'] == topic }
    end
    
    Rails.logger.info "已加载 #{@posts.size} 条帖子，共 #{@topics.size} 个话题"
  end
  
  # 获取指定话题的所有帖子
  def get_posts(topic)
    @posts_by_topic[topic] || []
  end
  
  # 获取所有可用话题
  def get_topics
    @topics
  end
  
  # 启动模拟实时更新服务
  def start_simulation
    @mutex.synchronize do
      return if @running
      @running = true
    end
    
    # 创建一个新线程来模拟实时数据
    Thread.new do
      Rails.logger.info "开始模拟实时数据更新..."
      
      while @running
        # 随机选择一个话题
        topic = @topics.sample
        
        # 从该话题的帖子中随机选择一个
        posts = @posts_by_topic[topic]
        if posts.any?
          post = posts.sample
          
          # 创建一个新的帖子对象，模拟新内容
          new_post = post.dup
          new_post['id'] = SecureRandom.hex(6)  # 生成新的ID
          new_post['timestamp'] = Time.now.utc.iso8601  # 更新时间戳
          new_post['like_count'] = rand(10..500)  # 随机点赞数
          new_post['comments_count'] = rand(0..100)  # 随机评论数
          
          # 渲染帖子的 HTML
          html = ApplicationController.renderer.render(
            partial: 'topics/post',
            locals: { post: new_post }
          )
          
          # 通过 Action Cable 广播新帖子
          ActionCable.server.broadcast("topic_#{topic}", { html: html })
          
          Rails.logger.info "已推送新帖子到话题 ##{topic}"
        end
        
        # 随机等待 3-10 秒再推送下一个帖子
        sleep rand(3..10)
      end
    end
  end
  
  # 停止模拟
  def stop_simulation
    @mutex.synchronize do
      @running = false
    end
    Rails.logger.info "停止模拟实时数据更新"
  end
end
