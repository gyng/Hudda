class Bot::Plugin
  require 'fileutils'
  require_relative 'util/settings'
  include Bot::Util::Settings

  def initialize(bot = nil)
    @bot = bot
    @plugin_name = self.class.to_s.split('::').last.downcase

    # Default settings
    @s ||= Hash.new([])
    @s[:trigger] = { @plugin_name.to_sym => [:call, 0] } unless @s.key?(:trigger)

    settings_path = if defined?(Bot) && defined?(Bot::SETTINGS_DIR)
                      Bot::SETTINGS_DIR
                    else
                      File.join(Dir.pwd, 'lib', 'settings')
                    end

    @settings_path ||= File.join(settings_path, 'plugins', "#{@plugin_name}.json")
    load_settings

    if bot.methods.include?(:register_trigger)
      @s[:trigger].each { |trigger, opts| bot.register_trigger(trigger, @plugin_name, *opts) }
    end

    bot.subscribe_plugin(@plugin_name) if @s[:subscribe] == true && bot.methods.include?(:subscribe_plugin)

    Bot.log.info("Loaded plugin #{self.class.name}")
  end

  def call(_m)
    Bot.log.info("Called empty plugin #{self.class.name}")
  end

  def on_connect(adapter, conn)
    # Callback when a connection to a server is ready and finalized (eg, registered with IRC)
    # @bot.address_str("irc:::myserver:::mychannel").reply("Betabot is here!")
  end

  def receive(m)
    # Receives every message from bot
  end

  def auth(level, m)
    @bot.auth(level, m)
  end

  def auth_r(level, m)
    if auth(level, m)
      true
    else
      m.reply('You are unauthorised for this.')
      false
    end
  end
end
