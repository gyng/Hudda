require 'unicode_utils/grep'
# require 'unicode_utils/char_name' # Loaded by unicode_utils/grep
require 'gemoji'

class Bot::Plugin::Unicode < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        ufind: [:find, 0, 'ufind <query> - Search for characters by Unicode description and emoji aliases.'],
        u: [:name, 0, 'u <query> - Returns the name of the Unicode characters of a string.'],
        efind: [:emoji, 0, 'e <emoji +> - Search for emoji by aliases (exact match)']
      },
      subscribe: false
    }

    super(bot)
  end

  def find(m = nil)
    if m.args.empty?
      m.reply @s[:trigger][:u][2]
    elsif m.args[0].length <= 2
      m.reply 'Pattern too short (< 3)'
    else
      matches = UnicodeUtils.grep(/#{m.args[0]}/i).map(&:to_s)
      emoji_match = find_emoji(m.args[0])
      emoji_match = emoji_match.raw if emoji_match

      if !matches.empty?
        m.reply(emoji_match)
        m.reply(matches[0..999].join)
        m.reply "#{matches.length} codepoints found. #{matches.length - 1000} omitted." if matches.length > 1000
      else
        m.reply 'No matches found.'
      end
    end
  end

  def name(m = nil)
    if m.args.empty?
      m.reply @s[:trigger][:uid][2]
    else
      m.reply(
        m.args
          .join(' ')
          .force_encoding('utf-8')
          .chars
          .map { |c| UnicodeUtils.char_name c }
          .join(', ')
          .slice(0, 1000)
      )
    end
  end

  def find_emoji(query)
    Emoji.find_by_alias(query)
  end

  def emoji(m = nil)
    results = m.args.map do |q|
      result = find_emoji(q.downcase)

      if result
        result.raw
      else
        q
      end
    end

    m.reply(results.join(' '))
  end
end
