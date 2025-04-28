# app/services/realtime_simulation_service.rb
class RealtimeSimulationService
  include Singleton

  # 配置常量
  SIMULATION_MIN_INTERVAL = 2 # seconds
  SIMULATION_MAX_INTERVAL = 5 # seconds
  POSTS_PER_PUSH = 1

  def initialize
    @running = false
    @thread = nil
    @mutex = Mutex.new
    # 依赖注入 MockPostService
    @post_service = MockPostService.instance
    Rails.logger.debug "RealtimeSimulationService initialized."
  end

  def start
    @mutex.synchronize do
      return if @running
      @running = true
    end

    Rails.logger.info "Starting real-time simulation..."
    @thread = Thread.new do
      while @running
        begin
          simulate_push
        rescue StandardError => e
          # 捕获线程内的异常，防止线程意外终止
          Rails.logger.error "[RealtimeSimulation] Error during simulation loop: #{e.message}\n#{e.backtrace.join("\n")}"
          # 可以选择在这里休眠一段时间，避免快速连续失败
          sleep SIMULATION_MIN_INTERVAL
        end
      end
      Rails.logger.info "Real-time simulation thread stopped."
    end
  end

  def stop
    @mutex.synchronize do
      return unless @running
      @running = false
    end

    Rails.logger.info "Stopping real-time simulation..."
    # 等待线程结束 (设置超时以防万一)
    @thread&.join(SIMULATION_MAX_INTERVAL + 5)
    @thread = nil
    Rails.logger.info "Real-time simulation stopped."
  end

  private

  def simulate_push
    # 获取当前有订阅者的话题 (使用TopicChannel提供的类方法)
    topics_with_subscribers = TopicChannel.topics_with_subscribers
    Rails.logger.debug "[RealtimeSimulation] 有订阅者的话题列表: #{topics_with_subscribers.inspect}"

    if topics_with_subscribers.empty?
      Rails.logger.debug "[RealtimeSimulation] No topics with subscribers. Sleeping."
      sleep rand(SIMULATION_MIN_INTERVAL..SIMULATION_MAX_INTERVAL)
      return
    end

    # 随机选择一个有订阅者的话题
    topic = topics_with_subscribers.sample
    Rails.logger.debug "[RealtimeSimulation] 随机选择了话题: #{topic}"

    # 获取该话题的连接 (使用TopicChannel提供的类方法)
    connections = TopicChannel.connections_for_topic(topic)
    Rails.logger.debug "[RealtimeSimulation] 话题 #{topic} 的连接列表: #{connections.inspect}"

    if connections.empty?
      Rails.logger.debug "[RealtimeSimulation] Topic ##{topic} has no active connections. Skipping."
      sleep rand(SIMULATION_MIN_INTERVAL..SIMULATION_MAX_INTERVAL) # 短暂休眠
      return
    end

    # 随机选择一个连接进行推送
    connection_id = connections.sample
    Rails.logger.debug "[RealtimeSimulation] 随机选择了连接: #{connection_id}"

    # 获取下一个帖子的 *数据*
    posts_data = @post_service.next_posts(connection_id, topic, POSTS_PER_PUSH)
    post_data = posts_data.first

    if post_data
      # 构建广播频道名称
      channel_name = "topic_#{topic}_#{connection_id}"
      Rails.logger.info "[RealtimeSimulation] 准备广播到频道: #{channel_name}, 数据ID: #{post_data['id']}"

      # 使用ApplicationController.render渲染帖子HTML
      begin
        rendered_html = ApplicationController.render(
          partial: 'topics/post',
          locals: { post: post_data }
        )
        
        # 广播渲染好的HTML和原始数据
        ActionCable.server.broadcast(channel_name, { 
          html: rendered_html,
          post: post_data  # 保留原始数据，便于日志和调试
        })
        
        Rails.logger.info "[RealtimeSimulation] Broadcasted new post (ID: #{post_data['id']}) to #{channel_name}"
      rescue => e
        Rails.logger.error "[RealtimeSimulation] Error rendering post template: #{e.message}\n#{e.backtrace.join("\n")}"
        # 如果渲染失败，至少发送原始数据
        ActionCable.server.broadcast(channel_name, { post: post_data })
      end
    else
      Rails.logger.debug "[RealtimeSimulation] No new post generated for #{connection_id} on topic ##{topic}."
    end

    # 随机等待下一次推送
    sleep rand(SIMULATION_MIN_INTERVAL..SIMULATION_MAX_INTERVAL)
  end
end
