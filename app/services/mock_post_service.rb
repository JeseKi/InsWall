require "singleton"
require "json"
require "set"
require "securerandom"

class MockPostService
  include Singleton

  DATA_FILE_PATH = Rails.root.join("data", "mock_data.json")

  attr_reader :topics

  def initialize
    @posts = []
    @topics = []
    @posts_by_topic = {}
    @mutex = Mutex.new

    # 按连接跟踪游标和已浏览帖子
    @cursors = {}
    @seen_posts = Hash.new { |h, k| h[k] = Set.new }

    load_mock_data
    Rails.logger.debug "MockPostService 初始化中..."
  end

  # 加载填充数据
  def load_mock_data
    begin
      json_data = File.read(DATA_FILE_PATH)
      @posts = JSON.parse(json_data)
      @topics = @posts.map { |post| post["topic"] }.uniq.sort

      @topics.each do |topic|
        @posts_by_topic[topic] = @posts.select { |post| post["topic"] == topic }
      end

      Rails.logger.info "从 #{DATA_FILE_PATH} 加载了 #{@posts.size} 个模板帖子，分布在 #{@topics.size} 个话题中"
    rescue StandardError => e
      Rails.logger.error "从 #{DATA_FILE_PATH} 加载模板数据失败: #{e.message}"
      @posts = []
      @topics = []
      @posts_by_topic = {}
    end
  end

  def get_topics
    @topics
  end

  def get_posts_count(topic)
    (@posts_by_topic[topic] || []).size
  end

  # 获取下一批帖子
  def next_posts(connection_id, topic, count = 5)
    connection_key = build_connection_key(connection_id, topic)
    template_posts = @posts_by_topic[topic] || []

    return [] if template_posts.empty?

    result_posts = []
    @mutex.synchronize do
      @cursors[connection_key] ||= 0

      count.times do
        post = get_next_post_for_connection(connection_key, template_posts)
        result_posts << post if post
      end
    end
    result_posts
  end

  # 重置游标
  def reset_cursor(connection_id, topic)
    connection_key = build_connection_key(connection_id, topic)
    @mutex.synchronize do
      @cursors[connection_key] = 0
      @seen_posts[connection_key].clear
      Rails.logger.debug "Reset cursor for #{connection_key}"
    end
  end

  private

  def build_connection_key(connection_id, topic)
    "#{connection_id}_#{topic}"
  end

  # 为指定连接获取逻辑上的"下一个"帖子
  def get_next_post_for_connection(connection_key, template_posts)
    current_cursor = @cursors[connection_key]
    topic = connection_key.split("_", 2)[1]

    if current_cursor < template_posts.size
      base_post = template_posts[current_cursor]
      new_post = create_new_post_from_template(base_post)

      @seen_posts[connection_key].add(new_post["id"])
      @cursors[connection_key] += 1

      new_post
    else
      new_post = generate_unique_new_post(connection_key, template_posts, topic)

      if new_post
        @cursors[connection_key] += 1
      end

      new_post
    end
  end

  # 基于填充数据创建帖子实例（新 ID, 时间戳等），用于生成填充数据
  def create_new_post_from_template(base_post)
    new_post = base_post.dup
    new_post["id"] = SecureRandom.hex(6)
    new_post["timestamp"] = Time.now.utc.iso8601
    new_post["like_count"] = rand(10..500)
    new_post["comments_count"] = rand(0..100)
    new_post
  end

  # 循环生成填充数据
  def generate_unique_new_post(connection_key, template_posts, topic)
    return nil if template_posts.empty? # 按理说不应该出现空模板数据

    attempts = 0
    max_attempts = 5

    begin
      base_post = template_posts.sample
      new_post = create_new_post_from_template(base_post)
      attempts += 1
      id_seen = @seen_posts[connection_key].include?(new_post["id"])
    end while id_seen && attempts < max_attempts

    if !id_seen
      @seen_posts[connection_key].add(new_post["id"])
      Rails.logger.debug "[MockPostService] Generated new post ID: #{new_post['id']} for #{connection_key} (attempt #{attempts})"
      new_post
    else
      Rails.logger.warn "[MockPostService] Failed to generate a unique new post ID for #{connection_key} after #{max_attempts} attempts."
      nil
    end
  end
end
