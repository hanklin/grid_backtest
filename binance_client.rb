# binance_client.rb
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'openssl'

class BinanceClient
  BASE_URL = 'https://api.binance.com'.freeze

  attr_reader :debug

  def initialize(debug: false)
    @debug = debug
  end

  private

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    # 優先用 min_version + TLS1.2（新版 Net::HTTP）
    if http.respond_to?(:min_version=)
      if OpenSSL::SSL.const_defined?(:TLS1_2_VERSION)
        http.min_version = OpenSSL::SSL::TLS1_2_VERSION
      end
    else
      # 舊版 Net::HTTP：用 ssl_version + :TLSv1_2
      http.ssl_version = :TLSv1_2 if http.respond_to?(:ssl_version=)
    end

    http.read_timeout = 10
    http.open_timeout = 5
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    # 優先使用 certifi 的 CA，如果沒有就用系統預設
    begin
      require 'certifi'
      http.ca_file = Certifi.where
    rescue LoadError
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      http.cert_store = store
    end

    http
  end

  def get(path, params = {})
    uri = URI.parse(BASE_URL + path)
    uri.query = URI.encode_www_form(params) unless params.empty?

    http = build_http(uri)
    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "HTTP #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  end

  public

  # 這裡加上可選的 start_time / end_time，之後可以拿來分段抓資料
  # start_time / end_time 為毫秒 timestamp（Binance API 規格）
  def klines(symbol, interval:, limit: 500, start_time: nil, end_time: nil)
    params = {
      symbol:  symbol,
      interval: interval,
      limit:   limit
    }
    params[:startTime] = start_time if start_time
    params[:endTime]   = end_time   if end_time

    get('/api/v3/klines', params)
  end

  def ticker_24h
    get('/api/v3/ticker/24hr')
  end
end
