# app/services/realtime_simulation_service.rb
class RealtimeSimulationService
  include Singleton

  SIMULATION_MIN_INTERVAL = 2 # seconds
  SIMULATION_MAX_INTERVAL = 5 # seconds
  POSTS_PER_PUSH = 1

  def initialize
    @running = false
    @thread = nil
    @mutex = Mutex.new
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
          Rails.logger.error "[RealtimeSimulation] Error during simulation loop: #{e.message}\n#{e.backtrace.join("\n")}"
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
    @thread&.join(SIMULATION_MAX_INTERVAL + 5)
    @thread = nil
    Rails.logger.info "Real-time simulation stopped."
  end

  private

  def simulate_push
    topics_with_subscribers = TopicChannel.topics_with_subscribers
    Rails.logger.debug "[RealtimeSimulation] 有订阅者的话题列表: #{topics_with_subscribers.inspect}"

    if topics_with_subscribers.empty?
      Rails.logger.debug "[RealtimeSimulation] 没有任何话题有订阅者，休眠中..."
      sleep rand(SIMULATION_MIN_INTERVAL..SIMULATION_MAX_INTERVAL)
      return
    end

    topics_with_subscribers.each do |topic|
      connections = TopicChannel.connections_for_topic(topic)
      Rails.logger.debug "[RealtimeSimulation] 话题 #{topic} 的连接列表: #{connections.inspect}"

      next if connections.empty?

      connections.each do |connection_id|
        Rails.logger.debug "[RealtimeSimulation] 正在推送给连接: #{connection_id}"

        posts_data = @post_service.next_posts(connection_id, topic, POSTS_PER_PUSH)
        post_data = posts_data.first

        if post_data
          channel_name = "topic_#{topic}_#{connection_id}"
          Rails.logger.info "[RealtimeSimulation] 准备广播到频道: #{channel_name}, 数据ID: #{post_data['id']}"

          begin
            rendered_html = ApplicationController.render(
              partial: "topics/post",
              locals: { post: post_data }
            )
            ActionCable.server.broadcast(channel_name, {
              html: rendered_html,
              post: post_data
            })
            Rails.logger.info "[RealtimeSimulation] Broadcasted new post (ID: #{post_data['id']}) to #{channel_name}"
          rescue => e
            Rails.logger.error "[RealtimeSimulation] Error rendering post template: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end
    end

    sleep rand(SIMULATION_MIN_INTERVAL..SIMULATION_MAX_INTERVAL)
  end
end
