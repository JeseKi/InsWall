class TopicChannel < ApplicationCable::Channel
  # 类变量用于跟踪每个话题的订阅者数量
  @@topic_subscribers = {}
  @@mutex = Mutex.new

  def subscribed
    topic = params[:topic]

    # 优先使用前端传递的connection_id参数
    @connection_id = params[:connection_id]
    
    # 添加日志记录连接ID信息
    Rails.logger.debug "[TopicChannel] 从参数接收到连接ID: #{@connection_id.inspect}"
    
    # 如果没有收到连接ID，则使用备用方法
    if @connection_id.blank?
      @connection_id = connection.connection_identifier || SecureRandom.hex(8)
      Rails.logger.debug "[TopicChannel] 使用备用连接ID: #{@connection_id}"
    end

    # 创建连接特定的频道
    channel_name = "topic_#{topic}_#{@connection_id}"
    Rails.logger.info "[TopicChannel] 订阅通道: #{channel_name}"
    stream_from channel_name

    # 增加话题订阅者计数
    @@mutex.synchronize do
      @@topic_subscribers[topic] ||= 0
      @@topic_subscribers[topic] += 1

      Rails.logger.info "话题 ##{topic} 的订阅者增加到 #{@@topic_subscribers[topic]}"
      Rails.logger.info "为连接 #{@connection_id} 注册了话题 ##{topic} 的订阅"
    end
  end

  def unsubscribed
    topic = params[:topic]
    
    # 减少话题订阅者计数
    @@mutex.synchronize do
      if @@topic_subscribers[topic]
        @@topic_subscribers[topic] -= 1
        Rails.logger.info "话题 ##{topic} 的订阅者减少到 #{@@topic_subscribers[topic]}"
        
        # 如果计数为0，从哈希表中移除该话题
        @@topic_subscribers.delete(topic) if @@topic_subscribers[topic] <= 0
      end
    end
  end
  
  # 类方法，检查话题是否有订阅者
  def self.has_subscribers?(topic)
    @@mutex.synchronize do
      (@@topic_subscribers[topic] || 0) > 0
    end
  end
  
  # 类方法，获取所有有订阅者的话题
  def self.topics_with_subscribers
    @@mutex.synchronize do
      @@topic_subscribers.keys
    end
  end
  
  # 类方法，获取话题的所有连接ID
  def self.connections_for_topic(topic)
    Rails.logger.debug "[TopicChannel] 开始获取话题 #{topic} 的连接列表"
    
    # 通过ActionCable的连接查询获取指定话题的所有连接
    connections = ActionCable.server.connections.select do |conn|
      # 检查连接是否订阅了指定话题
      conn.subscriptions.identifiers.any? do |identifier|
        begin
          parsed = JSON.parse(identifier)
          parsed["channel"] == "TopicChannel" && parsed["topic"] == topic
        rescue JSON::ParserError
          false
        end
      end
    end
    
    Rails.logger.debug "[TopicChannel] 话题 #{topic} 的总连接数: #{connections.size}"
    
    # 提取连接ID
    connection_ids = connections.map do |conn|
      conn.subscriptions.identifiers.map do |identifier|
        begin
          parsed = JSON.parse(identifier)
          if parsed["channel"] == "TopicChannel" && parsed["topic"] == topic
            # 修改: 检查 connection_id 而不是 session_id
            connection_id = parsed["connection_id"] || conn.connection_identifier
            Rails.logger.debug "[TopicChannel] 找到连接ID: #{connection_id} 用于话题 #{topic}"
            connection_id
          end
        rescue JSON::ParserError
          nil
        end
      end.compact
    end.flatten.uniq
    
    Rails.logger.debug "[TopicChannel] 话题 #{topic} 的连接ID列表: #{connection_ids.inspect}"
    connection_ids
  end
end
