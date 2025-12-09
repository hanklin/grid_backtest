# binance_price_client.rb
# frozen_string_literal: true

require_relative './binance_client'
require_relative './stats_utils'

class BinancePriceClient
  include StatsUtils

  def initialize(debug: false)
    @client = BinanceClient.new(debug: debug)
  end

  # interval -> 毫秒
  def interval_to_ms(interval)
    case interval
    when '1m'  then 60_000
    when '5m'  then 5 * 60_000
    when '15m' then 15 * 60_000
    when '1h'  then 60 * 60_000
    when '4h'  then 4 * 60 * 60_000
    when '1d'  then 24 * 60 * 60_000
    else
      raise ArgumentError, "Unsupported interval for backtest: #{interval}"
    end
  end

  # 統一回傳結構：
  # [{ open_time:, close_time:, open:, high:, low:, close:, volume: }, ...]
  #
  # limit 可能 > 1000，會自動分段抓取，最後保留「最近 limit 根」，
  # 並以 open_time 由舊到新排序。
  def fetch_recent_klines(symbol:, interval:, limit:)
    max_limit = 1000

    if limit <= max_limit
      raw = @client.klines(symbol, interval: interval, limit: limit)
    else
      raw = []
      interval_ms = interval_to_ms(interval)
      total_needed = limit

      # 粗略估一個最早時間點，從這裡往後抓到現在
      now_ms = (Time.now.to_f * 1000).to_i
      earliest_start_ms = now_ms - total_needed * interval_ms

      batch_start = earliest_start_ms

      while raw.size < total_needed
        batch_limit = [max_limit, total_needed - raw.size].min

        batch = @client.klines(
          symbol,
          interval: interval,
          limit: batch_limit,
          start_time: batch_start
        )

        break if batch.nil? || batch.empty?

        raw.concat(batch)

        last_close_ms = batch.last[6].to_i
        batch_start = last_close_ms + 1

        # 如果這一段不到 batch_limit，代表拉到「現在」附近了
        break if batch.size < batch_limit
      end

      # 以 open_time 排序，只留最近 limit 根
      raw.sort_by! { |r| r[0].to_i }
      raw = raw.last(limit)
    end

    raw.map do |r|
      {
        open_time:  r[0],
        open:       StatsUtils.to_f(r[1]),
        high:       StatsUtils.to_f(r[2]),
        low:        StatsUtils.to_f(r[3]),
        close:      StatsUtils.to_f(r[4]),
        volume:     StatsUtils.to_f(r[5]),
        close_time: r[6]
      }
    end
  end

  # 24h 資訊：只取到此 symbol 的一筆
  def fetch_24h_stats(symbol:)
    rows = @client.ticker_24h
    row  = rows.find { |x| x['symbol'] == symbol }
    return nil unless row

    {
      symbol:       row['symbol'],
      last_price:   StatsUtils.to_f(row['lastPrice'] || row['last_price']),
      quote_volume: StatsUtils.to_f(row['quoteVolume'] || row['quote_volume'])
    }
  end
end
