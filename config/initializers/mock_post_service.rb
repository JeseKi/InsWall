# 只在开发和生产环境中启动模拟服务，测试环境不启动
unless Rails.env.test?
  Rails.application.config.after_initialize do
    # 启动模拟实时数据更新服务
    Rails.logger.info "正在启动 Mock Post Service..."
    MockPostService.instance.start_simulation
  end
end
