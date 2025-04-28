require 'singleton'
require 'json'
require 'set'
require 'securerandom'

class MockPostService
  include Singleton

  # 配置常量
  DATA_FILE_PATH = Rails.root.join("data", "mock_data.json")

  attr_reader :topics # 允许外部读取话题列表

  def initialize
    @posts = []
    @topics = []
    @posts_by_topic = {}
    @mutex = Mutex.new # 保护共享状态

    # 按连接跟踪游标和已浏览帖子
    # key: "connection_id_topic"
    @cursors = {}
    @seen_posts = Hash.new { |h, k| h[k] = Set.new }

    load_mock_data
    Rails.logger.debug "MockPostService initialized."
  end

  # --- 数据加载与查询 ---

  def load_mock_data
    begin
      json_data = File.read(DATA_FILE_PATH)
      @posts = JSON.parse(json_data)
      @topics = @posts.map { |post| post["topic"] }.uniq.sort

      @topics.each do |topic|
        @posts_by_topic[topic] = @posts.select { |post| post["topic"] == topic }
      end

      Rails.logger.info "Loaded #{@posts.size} mock posts across #{@topics.size} topics from #{DATA_FILE_PATH}"
    rescue StandardError => e
      Rails.logger.error "Failed to load mock data from #{DATA_FILE_PATH}: #{e.message}"
      # 可以在这里进行更健壮的错误处理，例如加载备用数据或抛出异常
      @posts = []
      @topics = []
      @posts_by_topic = {}
    end
  end

  def get_topics
    @topics
  end

  def get_posts_count(topic)
    # 返回的是模板帖子的数量
    (@posts_by_topic[topic] || []).size
  end

  # --- 核心：获取下一批帖子 (基于连接状态) ---

  def next_posts(connection_id, topic, count = 5)
    connection_key = build_connection_key(connection_id, topic)
    template_posts = @posts_by_topic[topic] || []

    # 如果该话题没有帖子，直接返回空数组
    return [] if template_posts.empty?

    result_posts = []
    @mutex.synchronize do
      # 初始化游标（如果不存在）
      @cursors[connection_key] ||= 0

      count.times do
        post = get_next_post_for_connection(connection_key, template_posts)
        result_posts << post if post # 只有成功获取到帖子才加入结果
      end
    end
    result_posts
  end

  # --- 状态管理与帖子生成 ---

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
  # 注意：此方法需要在 Mutex 块内调用
  def get_next_post_for_connection(connection_key, template_posts)
    current_cursor = @cursors[connection_key]
    topic = connection_key.split('_', 2)[1] # 从 key 中反解 topic

    if current_cursor < template_posts.size
      # --- 情况 1: 还有模板帖子未浏览 ---
      base_post = template_posts[current_cursor]
      new_post = create_new_post_from_template(base_post)

      # 标记已看并递增游标
      @seen_posts[connection_key].add(new_post["id"])
      @cursors[connection_key] += 1

      new_post
    else
      # --- 情况 2: 模板帖子已浏览完，生成全新帖子 ---
      new_post = generate_unique_new_post(connection_key, template_posts, topic)

      if new_post
        # 如果成功生成新帖子，递增游标（标记这是第几个生成的帖子）
        @cursors[connection_key] += 1
      end
      # 注意：generate_unique_new_post 内部已处理 seen_posts

      new_post # 可能为 nil，如果无法生成
    end
  end

  # 基于模板创建帖子实例（新 ID, 时间戳等）
  def create_new_post_from_template(base_post)
    new_post = base_post.dup
    new_post["id"] = SecureRandom.hex(6)
    new_post["timestamp"] = Time.now.utc.iso8601
    new_post["like_count"] = rand(10..500)
    new_post["comments_count"] = rand(0..100)
    # 保留原始 topic 和其他可能不变的字段
    new_post
  end

  # 生成一个确保 ID 对此连接唯一的全新帖子
  # 注意：此方法需要在 Mutex 块内调用
  def generate_unique_new_post(connection_key, template_posts, topic)
    return nil if template_posts.empty? # 理论上在调用前已检查，防御性编程

    attempts = 0
    max_attempts = 5 # 防止无限循环

    begin
      base_post = template_posts.sample # 随机选一个模板
      new_post = create_new_post_from_template(base_post)
      attempts += 1
      # 检查此连接是否已见过此 ID
      id_seen = @seen_posts[connection_key].include?(new_post["id"])
      # 如果见过且尝试次数未达上限，则重试
    end while id_seen && attempts < max_attempts

    # 如果尝试多次后仍然 ID 冲突（极小概率），或者成功生成了唯一的
    if !id_seen
      @seen_posts[connection_key].add(new_post["id"])
      Rails.logger.debug "[MockPostService] Generated new post ID: #{new_post['id']} for #{connection_key} (attempt #{attempts})"
      return new_post
    else
      # 极小概率事件：多次尝试仍然生成重复 ID
      Rails.logger.warn "[MockPostService] Failed to generate a unique new post ID for #{connection_key} after #{max_attempts} attempts."
      return nil
    end
  end
end
