class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: { entitleri: [
        :call, 0,
        'Entitle Reverse Image harnesses the power of Google cloud technology ' +
        'and the information superhighway botnet to tell you what an image link is.'
      ]},
      subscribe: true,
      filters: ['http.*png', 'http.*gif', 'http.*jpg', 'http.*jpeg', 'http.*bmp'],
      timeout: 10,
      google_query: 'http://www.google.com/searchbyimage?&image_url=',
      guess_selector: '._hUb',
      user_agent: 'Mozilla/5.0 (Windows NT 6.0; rv:20.0) Gecko/20100101 Firefox/20.0',
      microsoft_computer_vision_api_key: 'Get from: https://www.microsoft.com/cognitive-services/en-US/subscriptions'
    }
    super(bot)
  end

  def call(m)
    check_filter(m)
  end

  def receive(m)
    check_filter(m)
  end

  def check_filter(m)
    line = String.new(m.text)

    @s[:filters].each do |regex|
      results = line.scan(Regexp.new(regex))

      unless results.empty?
        results.each do |result|
          Thread.new do
            timeout(@s[:timeout]) do
              guess_text = []

              guess = get_guess(result)
              guess_text.push(guess) unless guess.nil?

              guess_microsoft = get_guess_microsoft(result)
              unless guess_microsoft.nil?
                caption = guess_microsoft[:description][:captions][0]
                guess_text.push(caption[:text]) if caption[:confidence] > 0.25
                guess_text.push('NSFW') if guess_microsoft[:adult][:isAdultContent]
              end

              m.reply(guess_text.join(', ')) unless guess_text.empty?
            end
          end

          # Prevent double-matching
          line.gsub!(result, '')
        end
      end
    end
  end

  def get_guess_microsoft(url)
    puts "EntitleRI: Getting image analysis of #{url}"
    uri = URI('https://api.projectoxford.ai/vision/v1.0/analyze')
    uri.query = URI.encode_www_form({
        'visualFeatures' => 'Categories,Description,Tags,Faces,ImageType,Color,Adult'
    })

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Ocp-Apim-Subscription-Key'] = @s[:microsoft_computer_vision_api_key]
    request.body = {url: url}.to_json

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body, symbolize_names: true)
    puts "EntitleRI: parsed image analysis: #{parsed.inspect}"
    parsed
  rescue Exception => e
    puts "Error in Entitleri#get_guess_microsoft: #{e} #{e.backtrace}"
    nil
  end

  def get_guess(url)
    puts "EntitleRI: Getting best guess of #{url}"

    # Get redirect by spoofing User-Agent
    html = open(@s[:google_query] + url,
      "User-Agent" => @s[:user_agent],
      allow_redirections: :all,
      ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    )

    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    doc.css(@s[:guess_selector]).inner_text
  rescue Exception => e
    puts "Error in Entitleri#get_guess: #{e} #{e.backtrace}"
    nil
  end
end
