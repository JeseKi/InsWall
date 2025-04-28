class MockPostService
  # 单例模式，确保只有一个实例在运行
  include Singleton

  def initialize
    @running = false
    @posts = []
    @topics = []
    @posts_by_topic = {}
    # 每个话题的缓冲区
    @buffer_by_topic = {}
    # 线程安全锁
    @mutex = Mutex.new

    # 新增：按连接跟踪游标和已浏览帖子
    @cursors = {}  # {"connection_id_topic" => cursor_index}
    @seen_posts = Hash.new { |h, k| h[k] = Set.new }  # 记录每个连接已查看的帖子ID

    load_mock_data
  end

  # 加载 Mock 数据
  def load_mock_data
    # 读取 JSON 文件
    json_data = File.read(Rails.root.join("data", "mock_data.json"))
    @posts = JSON.parse(json_data)

    # 提取所有唯一的话题
    @topics = @posts.map { |post| post["topic"] }.uniq.sort

    # 按话题分组帖子
    @topics.each do |topic|
      @posts_by_topic[topic] = @posts.select { |post| post["topic"] == topic }
      # 初始化每个话题的缓冲区
      @buffer_by_topic[topic] = []
    end

    Rails.logger.debug "已加载 #{@posts.size} 条帖子，共 #{@topics.size} 个话题"
  end

  # 获取所有可用话题
  def get_topics
    @topics
  end

  # 获取指定话题的帖子，支持分页（兼容旧API，基于游标实现）
  def get_posts(topic, page = 1, per_page = 5)
    # 创建一个临时连接ID用于兼容旧的API调用
    temp_connection_id = "temp_#{SecureRandom.hex(4)}"

    # 返回分页数据
    next_posts(temp_connection_id, topic, per_page)
  end

  # 获取指定话题的帖子总数
  def get_posts_count(topic)
    (@posts_by_topic[topic] || []).size
  end

  # 生成一条新帖子并添加到缓冲区
  def generate_new_post(topic)
    posts = @posts_by_topic[topic]
    return nil if posts.empty?

    # 随机选择一个帖子作为模板
    post = posts.sample

    # 创建一个新的帖子对象，模拟新内容
    new_post = post.dup
    new_post["id"] = SecureRandom.hex(6)  # 生成新的ID
    new_post["timestamp"] = Time.now.utc.iso8601  # 更新时间戳
    new_post["like_count"] = rand(10..500)  # 随机点赞数
    new_post["comments_count"] = rand(0..100)  # 随机评论数

    # 将新帖子添加到缓冲区
    @buffer_by_topic[topic] << new_post

    new_post
  end

  # 从缓冲区获取一条帖子
  def get_post_from_buffer(topic)
    buffer = @buffer_by_topic[topic] || []
    return nil if buffer.empty?

    # 从缓冲区取出第一条帖子
    @buffer_by_topic[topic].shift
  end

  # 获取用于连接缓冲区的帖子（旧API，现在已不直接使用）
  def get_posts_for_buffer(topic, count = 10)
    posts = @posts_by_topic[topic] || []
    return [] if posts.empty?

    # 随机选择指定数量的帖子
    posts.sample(count).map do |post|
      # 创建一个新的帖子对象，模拟新内容
      new_post = post.dup
      new_post["id"] = SecureRandom.hex(6)  # 生成新的ID
      new_post["timestamp"] = Time.now.utc.iso8601  # 更新时间戳
      new_post["like_count"] = rand(10..500)  # 随机点赞数
      new_post["comments_count"] = rand(0..100)  # 随机评论数
      new_post
    end
  end

  # 新API：获取连接的下一批帖子，如果已经浏览完，则生成新的
  def next_posts(connection_id, topic, count = 5)
    connection_key = "#{connection_id}_#{topic}"

    @mutex.synchronize do
      # 初始化游标（如果不存在）
      @cursors[connection_key] ||= 0

      # 准备返回的帖子数组
      result_posts = []

      # 获取指定数量的帖子
      count.times do
        # 尝试获取下一个帖子
        post = next_post_for_connection(connection_id, topic)

        # 如果获取到了帖子，添加到结果数组
        result_posts << post if post
      end

      return result_posts
    end
  end

  # 获取连接的下一个帖子
  def next_post_for_connection(connection_id, topic)
    connection_key = "#{connection_id}_#{topic}"
    posts = @posts_by_topic[topic] || []

    # 如果话题没有帖子，返回nil
    return nil if posts.empty?

    # 初始化游标（如果不存在）
    @cursors[connection_key] ||= 0

    # 获取当前游标位置，并在下面使用它
    current_cursor = @cursors[connection_key]

    # 检查是否已经浏览完模板帖子
    if current_cursor >= posts.size
      # 已经浏览完所有模板帖子，生成一个新帖子
      new_post = generate_new_post_for_connection(connection_id, topic)

      # 游标递增
      @cursors[connection_key] += 1

      new_post
    else
      # 获取当前游标位置的帖子
      base_post = posts[current_cursor]

      # 游标递增
      @cursors[connection_key] += 1

      # 创建一个新的帖子对象，基于模板但带有新的ID
      new_post = base_post.dup
      new_post["id"] = SecureRandom.hex(6)  # 生成新的ID
      new_post["timestamp"] = Time.now.utc.iso8601  # 更新时间戳
      new_post["like_count"] = rand(10..500)  # 随机点赞数
      new_post["comments_count"] = rand(0..100)  # 随机评论数

      # 标记帖子ID为已浏览
      @seen_posts[connection_key].add(new_post["id"])

      new_post
    end
  end

  # 为特定连接生成全新帖子
  def generate_new_post_for_connection(connection_id, topic)
    connection_key = "#{connection_id}_#{topic}"
    posts = @posts_by_topic[topic] || []

    return nil if posts.empty?

    # 随机选择一个帖子作为模板
    base_post = posts.sample

    # 生成新帖子，确保ID不重复
    attempts = 0
    begin
      # 创建一个新的帖子对象
      new_post = base_post.dup
      new_post["id"] = SecureRandom.hex(6)  # 生成新的ID
      new_post["timestamp"] = Time.now.utc.iso8601  # 更新时间戳
      new_post["like_count"] = rand(10..500)  # 随机点赞数
      new_post["comments_count"] = rand(0..100)  # 随机评论数

      attempts += 1
    end while @seen_posts[connection_key].include?(new_post["id"]) && attempts < 5

    # 标记帖子ID为已浏览
    @seen_posts[connection_key].add(new_post["id"])

    # 记录生成了新帖子（仅在DEBUG模式）
    Rails.logger.debug "为连接 #{connection_id} 的话题 ##{topic} 生成了新帖子 ID: #{new_post["id"]}"

    new_post
  end

  # 重置连接的游标
  def reset_cursor(connection_id, topic)
    connection_key = "#{connection_id}_#{topic}"

    @mutex.synchronize do
      @cursors[connection_key] = 0
      @seen_posts[connection_key].clear
    end
  end

  # 启动模拟实时更新服务
  def start_simulation
    @mutex.synchronize do
      return if @running
      @running = true
    end

    # 创建一个新线程来模拟实时数据
    Thread.new do
      Rails.logger.debug "开始模拟实时数据更新..."

      while @running
        # 获取所有有订阅者的话题
        topics_with_subscribers = TopicChannel.topics_with_subscribers

        if topics_with_subscribers.empty?
          Rails.logger.debug "当前没有话题有订阅者，跳过推送"
          sleep rand(5..10)  # 如果没有订阅者，等待较短时间
          next
        end

        # 随机选择一个有订阅者的话题
        topic = topics_with_subscribers.sample

        # 获取该话题的所有连接
        connections = TopicChannel.connections_for_topic(topic)

        if connections.empty?
          Rails.logger.debug "话题 ##{topic} 没有活跃连接，跳过推送"
          sleep rand(5..10)
          next
        end

        # 随机选择一个连接
        connection_id = connections.sample

        Rails.logger.debug "准备向连接 #{connection_id} 的话题 ##{topic} 推送新帖子"

        # 获取下一个帖子（使用新的游标API）
        posts = next_posts(connection_id, topic, 1)
        post = posts.first

        if post
          # 渲染帖子的 HTML
          html = ApplicationController.renderer.render(
            partial: "topics/post",
            locals: { post: post }
          )

          # 通过 Action Cable 广播新帖子到特定连接
          ActionCable.server.broadcast("topic_#{topic}_#{connection_id}", { html: html })

          Rails.logger.info "已推送新帖子到连接 #{connection_id} 的话题 ##{topic}"
        end

        # 随机等待 10-30 秒再推送下一个帖子
        sleep rand(10..30)
      end
    end
  end

  # 停止模拟
  def stop_simulation
    @mutex.synchronize do
      @running = false
    end
    Rails.logger.debug "停止模拟实时数据更新"
  end
end
