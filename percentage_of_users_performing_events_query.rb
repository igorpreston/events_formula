module EventsFormula
  class PercentageOfUsersPerformingEventsQuery < Base
    def count
      return 0 unless scope.exists?

      ((external_user_ids(scope).size / external_user_ids(global_scope).size.to_f) * 100).round(2)
    end

    private

    def all_time_avg
      return 0 unless scope.exists?

      computed_data = computed_data_by_day(reduced_scope_by_day(scope_grouped_by_period, false))

      (computed_data.values.sum / computed_data.size.to_f).round(3)
    end

    def computed_data_by_day(data = reduced_scope_by_day)
      {}.tap do |result|
        data.each do |date, total_users_ids|
          users_ids = (total_users_ids & current_users_ids)

          result[date] = result_value(total_users_ids, users_ids)
        end
      end
    end

    %w[week month year].each do |period|
      define_method("computed_data_by_#{period}") do
        @computed_data ||= begin
          {}.tap do |result|
            reduced_scope_by_day.each_with_index do |(date, _value), index|
              next if date != begin_of_period(date) && result.any?

              end_point_index = computed_data_end_point_index(date, index, reduced_values.size)
              total_users_ids = reduced_values[index..end_point_index].flatten.uniq

              users_ids = (total_users_ids & current_users_ids)

              result[date] = result_value(total_users_ids, users_ids)
            end
          end
        end
      end
    end

    def current_users_ids
      @current_users_ids ||= scope.group(:external_user_id).distinct.pluck(:external_user_id)
    end

    def reduced_scope_by_day(grouped_scope = scope_grouped_by_day, skip_keys = true)
      values = grouped_scope.values

      {}.tap do |result|
        grouped_scope.each_with_index do |(date, _value), index|
          next if index < days_count && skip_keys

          result[date] = values[reduced_scope_from_index(index)..index].flatten.uniq
        end
      end
    end

    def reduced_values
      @reduced_values ||= reduced_scope_by_day.values
    end

    def result_value(total_users_ids, users_ids)
      total_users_ids.empty? ? 0 : (users_ids.size / total_users_ids.size.to_f).round(3) * 100
    end

    def scope_grouped_by(all_counts)
      all_counts.each_with_object(Hash.new { |h, k| h[k] = [] }) do |((external_user_id, date), count), res|
        res[date] << external_user_id unless count.zero? || res[date].include?(external_user_id)
        res
      end.sort.to_h
    end

    def scope_grouped_by_day
      @scope_grouped_by_day ||= begin
        all_counts = global_scope.group(:external_user_id)
                                 .group_by_day('events.created_at', range: range_period, series: true)
                                 .count
        scope_grouped_by(all_counts)
      end
    end

    def scope_grouped_by_period
      @scope_grouped_by_period ||= begin
        all_counts = global_scope.group(:external_user_id).group_by_period(period, 'events.created_at').count
        scope_grouped_by(all_counts)
      end
    end
  end
end
