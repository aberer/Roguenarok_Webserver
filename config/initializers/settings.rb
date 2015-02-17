ENV['RAILS_ENV'] ||= 'development'
ENV['MAILSERVICE_ADDRESS'] =  '127.0.0.1'
ENV['SERVER_IP'] = '127.0.0.1' unless defined? SERVER_IP  # 
ENV['SERVER_ADDR'] = 'http://localhost' unless defined? SERVER_ADDR
ENV['SERVER_NAME'] = 'localhost' unless defined? SERVER_NAME
ENV['MAIL_SENDER'] = 'localhost'
APP_CONFIG = YAML.load_file("#{RAILS_ROOT}/config/config.yml")[RAILS_ENV]