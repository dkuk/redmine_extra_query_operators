require_dependency 'query'

module ExtraQueryOperators
  module Patches
    module QueryModelPatch
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          class << self
            alias_method_chain :operators_by_filter_type, :date_range
            alias_method_chain :operators, :date_range
          end

          alias_method_chain :sql_for_field, :date_range
        end
      end

      module ClassMethods
        def operators_with_date_range
          o=operators_without_date_range
          if o["t>"].blank?
            o["t>"]=:label_eqo_after_date
            o["t<"]=:label_eqo_before_date
            o["t><"]=:label_eqo_between_date
            o["tm="]=:label_eqo_month_offset
            o["tw="]=:label_eqo_week_offset
            o["=r"]=:label_eqo_regexp
          end
          o
        end

        def operators_by_filter_type_with_date_range
          o=operators_by_filter_type_without_date_range
          unless o[:date].include?("t>")
            o[:date] = ["t><","t>","t<"] + o[:date] + ["tm=", "tw="]
            o[:date_past] = ["t><","t>","t<"] + o[:date_past] + ["tm=", "tw="]
            o[:string] << "=r"
            o[:text] << "=r"
          end
          o
        end
      end

      module InstanceMethods

        def get_date_range_from_string(date_str)
          if [?-,?+].include?(date_str[0])
            if [?w,?W,?m,?M].include?(date_str[-1])
              str_i=date_str[0..-2].to_i
              mode=date_str[-1]
            else
              str_i=date_str.to_i
              mode=?d
            end
            dt=case mode
              when ?w, ?W
                Time.now.at_end_of_week+str_i.week
              when ?m, ?M
                Time.now.at_beginning_of_month.months_ago(str_i*-1).at_end_of_month
              else
                (Date.today+str_i.days).to_time
            end
          else
            dt=(Date.parse(date_str) rescue Date.today).to_time
          end
          dt
        end

        def sql_for_field_with_date_range(field, operator, value, db_table, db_field, is_custom_filter=false)
          sql=case operator
            when "t>"
                dt=get_date_range_from_string(value.first.strip)
                ("#{db_table}.#{db_field} > '%s'" % [connection.quoted_date(dt.end_of_day)])
            when "t<"
                dt=get_date_range_from_string(value.first.strip)
                ("#{db_table}.#{db_field} < '%s'" % [connection.quoted_date(dt.at_beginning_of_day)])
            when "t><"
                dt=get_date_range_from_string(value.first.strip)-1.month
                ("#{db_table}.#{db_field} BETWEEN '%s' AND '%s'" % [connection.quoted_date(( dt.at_beginning_of_day rescue Date.today ).to_time.at_beginning_of_day), connection.quoted_date(( Date.parse(value[1]) rescue Date.today ).to_time.end_of_day)])
            when "tm="
              from=Time.now.at_beginning_of_month.months_ago(value.first.to_i*-1)
              to=from.at_end_of_month
              ("#{db_table}.#{db_field} BETWEEN '%s' AND '%s'" % [connection.quoted_date(from), connection.quoted_date(to)])
            when "tw="
              from=Time.now.at_beginning_of_week+(value.first.to_i).week
              to=Time.now.at_end_of_week+(value.first.to_i).week
              ("#{db_table}.#{db_field} BETWEEN '%s' AND '%s'" % [connection.quoted_date(from), connection.quoted_date(to)])
            when "=r"
              ("#{db_table}.#{db_field} RLIKE '#{connection.quote_string(value.first.to_s)}'")
            else
              sql_for_field_without_date_range(field, operator, value, db_table, db_field, is_custom_filter)
          end
          sql
        end
      end
    end

  end
end

unless Query.included_modules.include? ExtraQueryOperators::Patches::QueryModelPatch
  Query.send(:include, ExtraQueryOperators::Patches::QueryModelPatch)
end
