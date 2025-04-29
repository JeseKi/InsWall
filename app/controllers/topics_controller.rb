class TopicsController < ApplicationController
  def index
    @topics = MockPostService.instance.get_topics

    # 如果没有指定话题，随机选择一个话题并重定向
    if params[:topic].blank?
      random_topic = @topics.sample
      redirect_to topic_path(random_topic)
      return
    end

    @topic = params[:topic]
    @page = (params[:page] || 1).to_i

    # 使用会话 ID 作为连接标识
    connection_id = session.id.to_s

    @posts = MockPostService.instance.next_posts(connection_id, @topic, 5)

    @total_posts = MockPostService.instance.get_posts_count(@topic)
    @total_pages = (@total_posts.to_f / 5).ceil

    if @posts.empty? && @page == 1
      redirect_to root_path, alert: "找不到话题 ##{@topic}"
      return
    end

    if request.xhr?
      render partial: "posts", locals: { posts: @posts, topic: @topic }
      return
    end

    render :show
  end

  def show
    @topics = MockPostService.instance.get_topics
    @topic = params[:id]
    @page = (params[:page] || 1).to_i

    # 使用会话 ID 作为连接标识
    connection_id = session.id.to_s

    @posts = MockPostService.instance.next_posts(connection_id, @topic, 5)

    @total_posts = MockPostService.instance.get_posts_count(@topic)
    @total_pages = (@total_posts.to_f / 5).ceil

    if @posts.empty? && @page == 1
      redirect_to root_path, alert: "找不到话题 ##{@topic}"
      return
    end

    if request.xhr?
      render partial: "posts", locals: { posts: @posts, topic: @topic }
      nil
    end
  end
end
