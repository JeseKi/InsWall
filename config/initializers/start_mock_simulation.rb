# config/initializers/start_mock_simulation.rb
if Rails.env.development? || Rails.env.test? # 只在特定环境启动
  Rails.application.config.after_initialize do
    Rails.logger.info("Initializing and starting RealtimeSimulationService...")
    RealtimeSimulationService.instance.start

    # 确保应用退出时停止模拟线程
    at_exit do
      Rails.logger.info("Stopping RealtimeSimulationService on application exit...")
      RealtimeSimulationService.instance.stop
    end
  end
end
