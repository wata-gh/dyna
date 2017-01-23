module Dyna
  module Filterable
    def should_skip(table_name)
      if @options.table_names
        unless @options.table_names.include?(table_name)
          log(:debug, "skip table(with tables_names option) #{table_name}")
          return true
        end
      end

      if @options.exclude_table_names
        if @options.exclude_table_names.any? {|regex| table_name =~ regex}
          log(:debug, "skip table(with exclude_tables_names option) #{table_name}")
          return true
        end
      end

      false
    end
  end
end
