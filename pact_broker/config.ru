require 'fileutils'
require 'logger'
require 'sequel'
require 'pact_broker'
require 'delegate'
require 'rack/ssl-enforcer'

class DatabaseLogger < SimpleDelegator
  def info *args
    __getobj__().debug(*args)
  end
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      Sequel::DATABASES.each { |db| db.disconnect }
    end
  end
end

DATABASE_CREDENTIALS = {
  adapter: "postgres",
  user: ENV['PACT_BROKER_DATABASE_USERNAME'],
  password: ENV['PACT_BROKER_DATABASE_PASSWORD'],
  host: ENV['PACT_BROKER_DATABASE_HOST'],
  database: ENV['PACT_BROKER_DATABASE_NAME']
}

require './lib/validations'
require './lib/conf'
require './lib/rack-oauth2-bearer_checker'
require './lib/rack-oauth2-bearer_helpers'
require './lib/rack-attack_setup'

unless ENV['SKIP_HTTPS_ENFORCER'] == 'true'
  use Rack::SslEnforcer, :except => [Conf::HEART_BEAT_REGEX]
end

use Rack::Attack
use Rack::OAuth2::Bearer::Checker

app = PactBroker::App.new do | config |
  # change these from their default values if desired
  # config.log_dir = "./log"
  # config.auto_migrate_db = true
  # config.use_hal_browser = true
  config.logger = ::Logger.new($stdout)
  config.logger.level = Logger::WARN
  config.database_connection = Sequel.connect(DATABASE_CREDENTIALS.merge(logger: DatabaseLogger.new(config.logger), encoding: 'utf8'))
end

run app
