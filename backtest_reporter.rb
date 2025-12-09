# backtest_reporter.rb
# frozen_string_literal: true

module BacktestReporter
  module_function

  # [鍵名, 短欄位代碼(<=8 chars), 中文說明]
  COLUMN_DEFS = [
    [:number_of_grids,                         'grid',  '格數'],
    [:grid_step_pct,                           'gstep', '格距% (等比)'],
    [:number_of_matching_pairs,                'pairs', 'matching pairs 數'],
    [:theoretical_net_return_per_cycle_pct,    'th_cyc','理論單次 cycle 淨報酬%'],
    [:realized_avg_net_return_per_cycle_pct,   'rl_cyc','實際平均 cycle 淨報酬%'],
    [:total_net_return_pct,                    'tot%',  '總報酬%'],
    [:theoretical_net_return_per_day_pct,      'th_day','理論日報酬%'],
    [:step_to_sigma_ratio,                     'stpσ',  'step/σ 比'],
    [:best_by_total_net,                       'b_tot','最佳(總報酬)'],
    [:best_by_pairs,                           'b_lg', '最佳(對數)']
  ].freeze

  def print_results(symbol:, opts:, windows_results:)
    puts "Symbol: #{symbol}"
    puts "window_size_days=#{opts[:window_size_days]}, max_windows=#{opts[:max_windows]}, window_slide_days=#{opts[:window_slide_days]}"
    puts "min_number_of_grids=#{opts[:min_number_of_grids]}, max_number_of_grids=#{opts[:max_number_of_grids]}, grid_count_step=#{opts[:grid_count_step]}"
    puts "fee_rate=#{opts[:fee_rate]}, band_type=#{opts[:band_type]}, price_timeframe=#{opts[:price_timeframe]}"
    puts

    # 若完全沒有任何結果，直接輸出「資料不足」
    if windows_results.nil? || windows_results.empty?
      puts '資料不足：沒有足夠的歷史價格資料可供回測。'
      return
    end

    print_legend_once

    # 依 band_type + window_index 分組，確保輸出順序穩定
    grouped = windows_results.group_by { |w| [w[:band_type] || 'unknown', w[:window_index] || 0] }

    grouped.keys.sort.each do |(band_type, window_index)|
      window = grouped[[band_type, window_index]]
      next if window.nil? || window.empty?

      w = window.first

      band_label =
        case band_type.to_s
        when 'simple' then 'simple_quantile'
        when 'robust' then 'robust_band'
        else band_type.to_s
        end

      puts
      puts "=== Window #{window_index} | band_type=#{band_label} ==="

      # --- 這裡使用 backtest_main 塞進來的結構 ---
      band      = w[:band]      || {}
      vol_stats = w[:vol_stats] || {}

      lower      = band[:grid_lower_price]
      upper      = band[:grid_upper_price]
      width_pct  = band[:band_width_pct]
      sigma      = vol_stats[:sigma_15m_return_pct]
      mad        = vol_stats[:median_abs_15m_return_pct]

      # 舊版你想要的 summary line：
      # band: lower=..., upper=..., width_pct=..., σ_15m_return_pct=..., median_abs_15m_return_pct=...
      if lower && upper && width_pct && sigma && mad
        puts " band: lower=#{fmt(lower)}, upper=#{fmt(upper)}, " \
             "width_pct=#{fmt(width_pct)}, " \
             "σ_15m_return_pct=#{fmt(sigma)}, " \
             "median_abs_15m_return_pct=#{fmt(mad)}"
      elsif lower && upper && width_pct
        # 即使 vol 資訊缺，也至少輸出 band
        puts " band: lower=#{fmt(lower)}, upper=#{fmt(upper)}, width_pct=#{fmt(width_pct)}"
      else
        puts " band: （此 window 沒有可用的 band 資訊）"
      end

      results = w[:grid_results] || []
      if results.empty?
        puts " （此 window 資料不足，無回測結果）"
        next
      end

      # 決定欄位寬度：主要依短代碼長度，不受中文影響
      col_widths = COLUMN_DEFS.map do |(_key, short, _)|
        [short.size, 8].max + 2
      end

      # 表頭只顯示短代碼
      header_line = COLUMN_DEFS.each_with_index.map { |(_, short, _), i|
        short.center(col_widths[i])
      }.join
      puts header_line
      puts '-' * header_line.size

      results.each do |gr|
        row = COLUMN_DEFS.each_with_index.map do |(key, _short, _), i|
          val = gr[key]
          s =
            case key
            when :best_by_total_net, :best_by_pairs
              val ? '★' : ''
            else
              fmt(val)
            end
          s.rjust(col_widths[i] - 1) + ' '
        end.join
        puts row
      end
    end
  end

  # 只印一次 Legend，說明每個短欄位代碼的含義
  def print_legend_once
    return if defined?(@legend_printed) && @legend_printed

    puts 'Legend:'
    COLUMN_DEFS.each do |(_key, short, cname)|
      puts " #{short.ljust(8)}: #{cname}"
    end
    puts

    @legend_printed = true
  end

  def fmt(v)
    case v
    when nil
      ''
    when Float
      if v.abs >= 1000
        v < 0 ? format('%.2f', v) : format(' %.2f', v)
      else
        v < 0 ? format('%.4f', v) : format(' %.4f', v)
      end
    else
      v.to_s
    end
  end
end
