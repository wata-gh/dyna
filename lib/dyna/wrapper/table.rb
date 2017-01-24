module Dyna
  class DynamoDBWrapper
    class Table
      extend Forwardable
      include Logger::ClientHelper

      def_delegators(
        :@table,
        :table_name
      )

      def initialize(ddb, table, options)
        @ddb = ddb
        @table = table
        @options = options
      end

      def eql?(dsl)
        definition_eql?(dsl)
      end

      def update(dsl)
        unless provisioned_throughput_eql?(dsl)
          wait_until_table_is_active
          update_table(dsl_provisioned_throughput(dsl))
        end
        unless global_secondary_indexes_eql?(dsl)
          wait_until_table_is_active
          update_table_index(dsl, dsl_global_secondary_index_updates(dsl))
        end
        unless stream_specification_eql?(dsl)
          wait_until_table_is_active
          update_stream_specification(dsl_stream_specification(dsl))
        end
      end

      def delete
        log(:info, 'Delete Table', :red, "#{table_name}")
        
        unless @options.dry_run
          @ddb.delete_table(table_name: @table.table_name)
          @options.updated = true
        end
      end

      def definition
        Exporter.table_definition(@table).symbolize_keys
      end

      def wait_until_table_is_active
        log(:info, "waiting table #{@table.table_name} to be ACTIVE or deleted..", false)
        loop do
          begin
            desc = @ddb.describe_table(table_name: table_name).table
          rescue => e
            break
          end
          status = desc.table_status
          log(:info, "status... #{status}", false)
          break if desc.table_status == 'ACTIVE'
          sleep 3
        end
      end

      private
      def definition_eql?(dsl)
        definition == dsl.definition
      end

      def provisioned_throughput_eql?(dsl)
        self_provisioned_throughput == dsl_provisioned_throughput(dsl)
      end

      def self_provisioned_throughput
        definition.select {|k,v| k == :provisioned_throughput}
      end

      def dsl_provisioned_throughput(dsl)
        dsl.symbolize_keys.select {|k,v| k == :provisioned_throughput}
      end

      def global_secondary_indexes_eql?(dsl)
        self_global_secondary_indexes == dsl_global_secondary_indexes(dsl)
      end

      def self_global_secondary_indexes
        definition[:global_secondary_indexes]
      end

      def dsl_global_secondary_indexes(dsl)
        dsl.symbolize_keys[:global_secondary_indexes]
      end

      def dsl_global_secondary_index_updates(dsl)
        actual_by_name = (self_global_secondary_indexes || {}).group_by { |index| index[:index_name] }.each_with_object({}) do |(k, v), h|
          h[k] = v.first
        end
        expect_by_name = (dsl_global_secondary_indexes(dsl) || {}).group_by { |index| index[:index_name] }.each_with_object({}) do |(k, v), h|
          h[k] = v.first
        end
        params = []
        expect_by_name.each do |index_name, expect_index|
          actual_index = actual_by_name[index_name]
          unless actual_index
            unless params.empty?
              log(:warn, 'Can not add multiple GSI at once', :yellow, index_name)
              next
            end
            params << {create: expect_index}
          end
        end

        expect_by_name.each do |index_name, expect_index|
          actual_index = actual_by_name.delete(index_name)
          if actual_index != nil &&
            actual_index[:provisioned_throughput] != expect_index[:provisioned_throughput]
            if params.any? { |param| param[:update] }
              log(:warn, 'Can not update multiple GSI at once', :yellow, index_name)
              next
            end
            params << {update: {
              index_name: index_name,
              provisioned_throughput: expect_index[:provisioned_throughput]
            }}
          end
        end

        actual_by_name.each do |index_name, actual_index|
          if params.any? { |param| param[:delete] }
              log(:warn, 'Can not delete multiple GSI at once', :yellow, index_name)
              next
          end
          params << {delete: { index_name: index_name }}
        end

        params
      end

      def stream_specification_eql?(dsl)
        actual = self_stream_specification
        expect = dsl_stream_specification(dsl)
        if (actual == nil || actual[:stream_specification] == nil) &&
           (expect == nil || expect[:stream_specification] == nil || expect[:stream_specification][:stream_enabled] == false)
          return true
        end
        actual == expect
      end

      def self_stream_specification
        definition.select {|k,v| k == :stream_specification}
      end

      def dsl_stream_specification(dsl)
        dsl.symbolize_keys.select {|k,v| k == :stream_specification}
      end

      def update_stream_specification(dsl)
        log(:info, "  table: #{@table.table_name}(update stream spec)\n".green + Dyna::Utils.diff(self_stream_specification, dsl, :color => @options.color, :indent => '    '), false)
        unless @options.dry_run
          params = { table_name: @table.table_name }.merge(dsl)
          @ddb.update_table(params)
          @options.updated = true
        end
      end

      def update_table(dsl)
        log(:info, "  table: #{@table.table_name}\n".green + Dyna::Utils.diff(self_provisioned_throughput, dsl, :color => @options.color, :indent => '    '), false)
        unless @options.dry_run
          params = dsl.dup
          params[:table_name] = @table.table_name
          @ddb.update_table(params)
          @options.updated = true
        end
      end

      def update_table_index(dsl, index_params)
        log(:info, "  table: #{@table.table_name}(update GSI)".green, false)
        index_params.each do |index_param|
          if index_param[:create]
            log(:info, "  index: #{index_param[:create][:index_name]}(create GSI)".cyan, false)
            log(:info, "    => #{index_param[:create]}".cyan, false)
          end
          if index_param[:update]
            log(:info, "  index: #{index_param[:update][:index_name]}(update GSI)".green, false)
            log(:info, "    => #{index_param[:update]}".green, false)
          end
          if index_param[:delete]
            log(:info, "  index: #{index_param[:delete][:index_name]}(delete GSI)".red, false)
            log(:info, "    => #{index_param[:delete]}".red, false)
          end
        end

        unless @options.dry_run
          params = {
            table_name: @table.table_name,
            attribute_definitions: dsl.symbolize_keys[:attribute_definitions],
            global_secondary_index_updates: index_params,
          }
          @ddb.update_table(params)
          @options.updated = true
        end
      end
    end
  end
end
