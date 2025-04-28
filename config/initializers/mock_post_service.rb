Rails.application.config.after_initialize do
  # 启动模拟实时数据更新服务
  Rails.logger.info "正在启动 Mock Post Service..."
  MockPostService.instance.start_simulation
end
