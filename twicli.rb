require 'parsedate'
class Tweet
  attr_reader :user, :text
  def initialize(user, text, created_at)
    @user = user
    @text = text
    @created_at = created_at
  end
  def to_s(longest_username=0,terminal_width=80)
    username = "%#{longest_username}s" % @user
    prompt = "#{@created_at.strftime('%H:%M')}: #{username}: "
    indent = prompt.length
    wrap_and_indent(prompt + @text, terminal_width, indent)
  end

  def wrap_and_indent(txt, wrap, indent)
    result = ''
    current_line = ''
    next_space = ''
    swallow_space = false
    txt.scan(/\S+|\s+/).each do |word|
      if word =~ /\s+/
        next_space = word
        next
      end
      if current_line.length + word.length + 1 > wrap
        result += current_line + "\n"
        current_line = ''
        next_space = ''
        current_line += ' '*indent if indent>0
      end
      current_line += next_space + word
    end
    result + current_line
  end
end

require 'rubygems'
require 'open-uri'
require 'xmlsimple'
class Twicli
  FRIENDS_TL_URL = "http://twitter.com/statuses/friends_timeline.xml"

  def initialize(credentials)
    @username = credentials[:username]
    @password = credentials[:password]
    @refresh_interval = 60
    @last_refresh = nil
    @longest_username = 0
  end

  def refresh
    # Log in to twitter account get tweets
    xml = open(FRIENDS_TL_URL, :http_basic_authentication => [@username, @password]).readlines.join('')
    doc = XmlSimple.xml_in(xml)
    tweets = []
    doc['status'].each do |status|
      d = ParseDate.parsedate(status['created_at'].first)
      created_at = Time.local(*(d[0,6].reverse<<d[8]<<nil<<nil<<d[7])) # yuck
      if @last_refresh.nil? || created_at > @last_refresh
        name = status['user'].first['name'].first
        text = status['text'].first
        @longest_username = [@longest_username, name.length].max
        tweets << Tweet.new(name, text, created_at)
      end
    end
    @last_refresh = Time.now
    # Return new tweets
    return tweets
  rescue OpenURI::HTTPError => e
    puts "-- Error: #{e} --"
  end

  def display(tweet)
    puts tweet.to_s(@longest_username)
    puts
  end

  def monitor
    loop do
      new_tweets = refresh
      if new_tweets.size > 0
        puts '-- ' + Time.now.strftime('%H:%M') + ' ' + '-'*71;
        new_tweets.reverse.each do |tweet|
          display(tweet)
        end
      else
        STDERR.print '-- ' + Time.now.strftime('%H:%M') + " --\r"
      end
      sleep @refresh_interval
    end
  end
end

username, password = File.open('credentials').readlines.map { |line| line.chomp }
Twicli.new(:username => username, :password => password).monitor
