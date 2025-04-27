class TopicChannel < ApplicationCable::Channel
  def subscribed
    stream_from "topic_#{params[:topic]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
