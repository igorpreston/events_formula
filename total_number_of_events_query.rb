module EventsFormula
  class TotalNumberOfEventsQuery < Base
    def count
      return 0 unless scope.any?

      scope.size
    end

    private

    def all_time_avg
      return 0 unless scope.any?

      global_scope_grouped = scope.group_by_period(period, 'events.created_at').count

      computed_data = computed_data_by_day(global_scope_grouped, false)

      (computed_data.values.sum / computed_data.size.to_f).round(3)
    end

    def computed_data_by_day(grouped_scope = scope_grouped_by_day, skip_keys = true)
      values = grouped_scope.values

      {}.tap do |result|
        grouped_scope.each_with_index do |(date, _value), index|
          next if index < days_count && skip_keys

          result[date] = values[reduced_scope_from_index(index)..index].sum
        end
      end
    end

    %w[week month year].each do |period|
      define_method("computed_data_by_#{period}") do
        @computed_data ||= begin
          {}.tap do |result|
            computed_data_by_day.each_with_index do |(date, _value), index|
              next if date != begin_of_period(date) && result.any?

              end_point_index = computed_data_end_point_index(date, index, computed_values.size)
              result[date] = computed_values[index..end_point_index].sum
            end
          end
        end
      end
    end

    def computed_values
      @computed_values ||= computed_data_by_day.values
    end

    def scope_grouped_by_day
      scope.group_by_day('events.created_at', range: range_period).count
    end
  end
end
