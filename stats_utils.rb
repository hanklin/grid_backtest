# stats_utils.rb
# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

module StatsUtils
  module_function

  def to_f(v)
    return 0.0 if v.nil?
    v.to_f
  end

  # prices: [Float] in time order
  # return: [Float] log returns
  def log_returns(prices)
    arr = prices.map { |p| to_f(p) }.compact
    return [] if arr.size < 2
    rets = []
    (1...arr.size).each do |i|
      next if arr[i] <= 0.0 || arr[i - 1] <= 0.0
      rets << Math.log(arr[i] / arr[i - 1])
    end
    rets
  end

  # sample standard deviation
  def stdev(values)
    vals = values.map { |v| to_f(v) }
    n = vals.size
    return 0.0 if n < 2
    mean = vals.sum / n.to_f
    var = vals.map { |v| (v - mean) ** 2 }.sum / (n - 1).to_f
    Math.sqrt(var)
  end

  def median(values)
    vals = values.map { |v| to_f(v) }.sort
    n = vals.size
    return 0.0 if n == 0
    mid = n / 2
    if n.odd?
      vals[mid]
    else
      (vals[mid - 1] + vals[mid]) / 2.0
    end
  end

  def median_abs(values)
    abs_vals = values.map { |v| to_f(v).abs }
    median(abs_vals)
  end

  # q in [0,1]
  def quantile(values, q)
    vals = values.map { |v| to_f(v) }.sort
    n = vals.size
    return 0.0 if n == 0
    q = [[q.to_f, 0.0].max, 1.0].min
    pos = q * (n - 1)
    lower = vals[pos.floor]
    upper = vals[pos.ceil]
    lower + (upper - lower) * (pos - pos.floor)
  end

  # 幾何網格：由上下界與總格數取得每格等比增幅 (%)
  # number_of_grids: 在 [lower, upper] 之間的段數（格數）
  def grid_step_pct_from_bounds(lower:, upper:, number_of_grids:)
    lower = to_f(lower)
    upper = to_f(upper)
    g = number_of_grids.to_i
    return 0.0 if g <= 0 || lower <= 0.0 || upper <= lower
    ratio_step = (upper / lower) ** (1.0 / g.to_f)
    (ratio_step - 1.0) * 100.0
  end

  # 幾何網格的「單次 cycle」理論淨報酬（小數，如 0.002 => 0.2%）
  # lower, upper: price band
  # grids: number_of_grids（同上）
  # fee_rate: 手續費比率，例如 0.00075
  #
  # 使用你先前的近似公式：
  # profit_per_grid = (1 - c) * r_step - 1 - c
  # where r_step = (upper/lower)^(1/grids)
  def geometric_grid_profit_pct(lower:, upper:, grids:, fee_rate:)
    lower = to_f(lower)
    upper = to_f(upper)
    g = grids.to_i
    c = fee_rate.to_f
    return 0.0 if g <= 0 || lower <= 0.0 || upper <= lower
    r = upper / lower
    r_step = r ** (1.0 / g.to_f)
    ((1.0 - c) * r_step) - 1.0 - c
  end

  # σ_15m：15 分鐘 log-return 的標準差（轉為百分比）
  def sigma_15m_return_pct(price_series)
    rets = log_returns(price_series)
    stdev(rets) * 100.0
  end

  # median_abs_15m_return_pct：15 分鐘 log-return 絕對值的中位數（百分比）
  def median_abs_15m_return_pct(price_series)
    rets = log_returns(price_series)
    median_abs(rets) * 100.0
  end
end
