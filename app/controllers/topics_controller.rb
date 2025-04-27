class TopicsController < ApplicationController
  def index
    # 从 MockPostService 获取所有话题
    @topics = MockPostService.instance.get_topics
  end

  def show
    # 获取指定话题的帖子
    @topic = params[:id]
    @posts = MockPostService.instance.get_posts(@topic)
    
    # 如果找不到该话题的帖子，重定向到首页
    redirect_to root_path, alert: "找不到话题 ##{@topic}" if @posts.empty?
  end
end
