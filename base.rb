module EventsFormula
  class Base
    def initialize(scope:, global_scope: nil, date_from: nil, date_to: nil, period: nil, days_count: nil)
      @scope = scope
      @global_scope = global_scope
      @date_from = date_from
      @date_to = date_to
      @period = period
      @days_count = days_count
    end

    def aggregate
      @aggregated_data = scope.exists? ? send("computed_data_by_#{period}") : empty_aggregated_data

      {}.tap do |hash|
        hash[:data] = aggregated_data
        hash[:meta] = meta
      end
    end

    def count
      raise NotImplementedError
    end

    private

    attr_reader :scope, :global_scope, :aggregated_data, :date_from, :date_to, :days_count, :period

    %i[all_time_avg computed_data_by_day computed_data_by_week
       computed_data_by_month computed_data_by_year].each do |method|
      define_method method do
        raise NotImplementedError
      end
    end

    def begin_of_period(date)
      date.public_send("beginning_of_#{period}")
    end

    def computed_data_end_point_index(date, index, values)
      end_point_index = (index + (days_in_the_period(date) - 1))
      end_point_index > (values.size - 1) ? -1 : end_point_index
    end

    def dates
      date_picker.public_send("get_#{period}s")
    end

    def date_picker
      Service::DatePicker.new(date_from: date_from.beginning_of_day, date_to: date_to.end_of_day)
    end

    def days_in_the_period(date)
      (end_of_period(date) - begin_of_period(date)).to_i + 1
    end

    def empty_aggregated_data
      dates.each_with_object({}) do |date, result|
        result[date] = 0
      end
    end

    def end_of_period(date)
      date.public_send("end_of_#{period}")
    end

    def external_user_ids(events)
      events.group(:external_user_id).select(:external_user_id).distinct.count
    end

    def meta
      {
        time_period_avg: time_period_avg,
        all_time_avg: all_time_avg
      }
    end

    def range_period
      (date_from - days_count).beginning_of_day..date_to.end_of_day
    end

    def reduced_scope_from_index(index)
      from_index = index - days_count
      from_index.negative? ? 0 : from_index
    end

    def time_period_avg
      return 0 unless scope.exists?

      data = send("computed_data_by_#{period}")
      (data.values.sum / data.size.to_f).round(3)
    end
  end
end
