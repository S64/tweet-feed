require 'active_support'
require 'active_support/core_ext'
require 'sinatra/base'
require 'sinatra/reloader'
#require 'parse-ruby-client'
require 'twitter'
require 'slim'
require 'time'

class App < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
  end

  #Parse.create :application_id => '',
  #             :api_key => '',
  #             :quiet => false

  get '/feed.atom' do
    token  = params[:access_token]
    secret = params[:access_token_secret]

    first_time = Time.now.beginning_of_day
    #times = [ first_time, first_time.yesterday, first_time.yesterday.yesterday ]
    times = [ first_time.yesterday.yesterday.yesterday.yesterday ]

    items = []
    times.each do |time|
      qsince = time.yesterday.strftime('%F')
      quntil = time.strftime('%F')
      items.push({
        url: ('http://powerful-cove-6439.herokuapp.com/?access_token=%s&access_token_secret=%s&since=%s&until=%s' % [token, secret, qsince, quntil ]),
        updated: time.to_datetime.rfc3339(9),
        content: generate_html(token, secret, nil, quntil, qsince),
        title: time.yesterday.strftime('%Fのツイートまとめ')
      })
    end

    slim :feed, locals: { items: items }, content_type: 'text/plain'
  end

  get '/' do
    generate_html params[:access_token], params[:access_token_secret], params[:timezone], params[:until], params[:since]
  end

  def generate_html(token, secret, timezone, quntil, qsince)

    timezone ||= 'JST'

    if quntil.present? && qsince.present? then
      quntil = Time.parse(quntil + ' ' + timezone)
      qsince = Time.parse(qsince + ' ' + timezone)
    end

    quntil ||= Time.parse('00:00 ' + timezone, Time.now).beginning_of_day
    qsince ||= quntil.yesterday.beginning_of_day

    if timezone.blank? || quntil.blank? || qsince.blank? then
      halt 400, 'timezone or until or since invalid'
    end

    if token.blank? || secret.blank? then
      halt 400, 'access_token & access_token_secret is required'
    end

    twtr = Twitter::REST::Client.new do |c|
      c.consumer_key        = ENV['TWTR_CONSUMER_KEY']
      c.consumer_secret     = ENV['TWTR_CONSUMER_SECRET']
      c.access_token        = token
      c.access_token_secret = secret
    end

    user = nil
    begin
      user = twtr.verify_credentials
    rescue
      halt 400, 'invalid token'
    end

    q = 'since:%s until:%s from:%s' % [qsince.strftime('%F_%T_%Z'), quntil.strftime('%F_%T_%Z'), user.screen_name]
    search_result = twtr.search q, result_type: 'recent', count: 100

    showconvs = []
    tweets = (search_result.to_a).sort do |a, b|
      a.id <=> b.id
    end

    if tweets.count < 1 then
      halt 400, 'hogemoge'
    end

    tweets.count.times do |key|
      t = tweets[key]
      tprev = tweets[key - 1]
      tnext = tweets[key + 1]

      reply_to = t.in_reply_to_status_id

      if reply_to.present? && ( (reply_to != tprev.try(:id)) && (reply_to != tnext.try(:id)) ) then
        showconvs.push t.id
      end
    end


    slim :body, locals: { tweets: tweets, user: user, showconvs: showconvs}
  end

end
