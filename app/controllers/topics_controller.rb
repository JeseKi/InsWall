class TopicsController < ApplicationController
  def index
    # 获取所有话题
    @topics = MockPostService.instance.get_topics

    # 随机选择一个话题并重定向
    if params[:topic].blank?
      random_topic = @topics.sample
      redirect_to topic_path(random_topic)
      return
    end

    # 如果指定了话题，则显示该话题
    @topic = params[:topic]
    @page = (params[:page] || 1).to_i
    
    # 使用会话 ID 作为连接标识
    connection_id = session.id.to_s
    
    # 从服务获取帖子，使用游标分页
    @posts = MockPostService.instance.next_posts(connection_id, @topic, 5)
    
    @total_posts = MockPostService.instance.get_posts_count(@topic)
    @total_pages = (@total_posts.to_f / 5).ceil

    # 如果找不到该话题的帖子，重定向到随机话题
    if @posts.empty? && @page == 1
      redirect_to root_path, alert: "找不到话题 ##{@topic}"
      return
    end

    # 如果是 AJAX 请求，只返回帖子部分
    if request.xhr?
      render partial: "posts", locals: { posts: @posts, topic: @topic }
      return
    end

    render :show
  end

  def show
    # 获取指定话题的帖子
    @topics = MockPostService.instance.get_topics
    @topic = params[:id]
    @page = (params[:page] || 1).to_i
    
    # 使用会话 ID 作为连接标识
    connection_id = session.id.to_s
    
    # 从服务获取帖子，使用游标分页
    @posts = MockPostService.instance.next_posts(connection_id, @topic, 5)
    
    @total_posts = MockPostService.instance.get_posts_count(@topic)
    @total_pages = (@total_posts.to_f / 5).ceil

    # 如果找不到该话题的帖子，重定向到首页
    if @posts.empty? && @page == 1
      redirect_to root_path, alert: "找不到话题 ##{@topic}"
      return
    end

    # 如果是 AJAX 请求，只返回帖子部分
    if request.xhr?
      render partial: "posts", locals: { posts: @posts, topic: @topic }
      nil
    end
  end
end
