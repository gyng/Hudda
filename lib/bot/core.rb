module Bot
  require 'json'
  require 'date'
  require 'logger'
  require 'timeout'
  require 'colorize'

  # require 'rbconfig'
  # if (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
  # end

  require_relative 'adapter'
  require_relative 'plugin'

  class << self
    attr_accessor :log

    def log
      if !@log
        @log = Logger.new(STDOUT)
        @log.level = Logger::WARN if ENV['TEST'] # Set in spec_helper.rb
        @log.formatter = -> severity, datetime, progname, message do
          color = case severity
            when "FATAL";   :red
            when "ERROR";   :red
            when "WARN";    :red
            when "INFO";    :default
            when "DEBUG";   :default
            when "UNKNOWN"; :default
          end
          "#{(severity[0] + ' ' + datetime.to_s + ' | ').colorize(color)}#{message}\n"
        end
      end
      @log
    end
  end

  class Core
    require_relative 'core/message'
    require_relative 'core/object_loader'
    include Bot::Core::ObjectLoader

    attr_reader :adapters, :plugins, :settings, :enabled_adapters, :enabled_plugins
    START_TIME = Time.now

    def initialize(bot_settings_filename)
      @adapters = {}
      @plugins = {}
      @plugin_mapping = {}
      @subscribed_plugins = []
      @settings = nil
      @settings_filename = bot_settings_filename
      Bot.const_set("ROOT_DIR", File.join(Dir.pwd, "lib")) unless defined?(Bot::ROOT_DIR)

      load_settings
      load_objects('adapter')
      load_objects('plugin')
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."

      start_adapters('irc')
    end

    def start_adapters(regex='.*')
      send_to_objects(@adapters, :connect, regex)
    end

    def stop_adapters(regex='.*')
      send_to_objects(@adapters, :shutdown, regex)
    end

    def send_to_objects(list, method, regex='.*')
      selected = list.select { |k, v| k.to_s.match(/#{regex}/i) }
      selected.each { |k, v| v.send(method) }
    end

    def load_settings
      @settings = JSON.parse(File.read(@settings_filename), symbolize_names: true)
    rescue => e
      Bot.log.fatal "Failed to load bot settings from file #{@settings_filename}. \
                     Check that file exists and permissions are set."
      raise e
    end

    def trigger_plugin(trigger, m)
      case trigger
      when 'shutdown'
        shutdown
      when 'restart'
        restart
      else
        to_call = @plugin_mapping[trigger.to_sym]
        # Plugin responds to trigger
        return @plugins[to_call].call(m) if @plugins.has_key?(to_call)
      end

      nil
    end

    def publish(m)
      # Plugin listens in to all messages
      @subscribed_plugins.each { |p| @plugins[p].receive(m) }
    end

    def register_trigger(trigger, plugin)
      @plugin_mapping[trigger.to_sym] = plugin.to_sym
    end

    def subscribe_plugin(plugin)
      Bot.log.warn 'subscribing ' + plugin.to_s
      @subscribed_plugins.push(plugin.to_sym)
      puts @subscribed_plugins.inspect
    end

    def reload(type, name=nil)
      load_settings

      if (type == nil)
        load_objects('adapter')
        load_objects('plugin')
      elsif (name == nil)
        load_objects(type)
      else
        load_curry(type).call(name)
      end
    end

    def restart
      $restart = true
      shutdown
    end

    def shutdown
      # We don't want this to take too long, but give adapters some time to shutdown
      EM.add_timer(1) do
        stop_adapters
        EM.stop
      end
    end
  end
end