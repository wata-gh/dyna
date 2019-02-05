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
        unless billing_mode_eql?(dsl) && provisioned_throughput_eql?(dsl)
          update_table(dsl)
        end
        unless global_secondary_indexes_eql?(dsl)
          wait_until_table_is_active
          update_table_index(dsl, dsl_global_secondary_index_updates(dsl))
        end
        unless stream_specification_eql?(dsl)
          wait_until_table_is_active
          update_stream_specification(dsl_stream_specification(dsl))
        end
        unless time_to_live_eql?(dsl)
          update_time_to_live(dsl)
        end
        unless auto_scaling_eql?(dsl)
          update_auto_scaling(dsl)
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

      def aws_time_to_live
        @ttl ||= @ddb.describe_time_to_live(table_name: @table.table_name).time_to_live_description
      end

      def time_to_live_eql?(dsl)
        wait_until_table_is_active
        ttl = aws_time_to_live
        unless %w/ENABLED DISABLED/.include?(ttl.time_to_live_status)
          raise "time to live status is #{ttl.time_to_live_status} and must be ENABLED or DISABLED to apply"
        end
        same_status = dsl.time_to_live_specification.enabled.to_s == 'false' && ttl.time_to_live_status == 'DISABLED' || dsl.time_to_live_specification.enabled.to_s == 'true' && ttl.time_to_live_status == 'ENABLED'
        same_name = dsl.time_to_live_specification.attribute_name.to_s == ttl.attribute_name

        same_status && same_name
      end

      def auto_scaling_eql?(dsl)
        scalable_targets_eql?(dsl) && scaling_policies_eql?(dsl)
      end

      def scalable_targets_eql?(dsl)
        df = definition[:scalable_targets].map do |target|
          cmp = target.to_h
          cmp.delete(:creation_time)
          cmp.delete(:role_arn)
          Dyna::Utils.normalize_hash(cmp)
        end
        df.sort_by {|s| s[:scalable_dimension] } == dsl[:scalable_targets].map { |target| Dyna::Utils.normalize_hash(target) }.sort_by {|s| s[:scalable_dimension] }
      end

      def scaling_policies_for_diff
        definition[:scaling_policies].map { |policy|
          #Dyna::Utils.normalize_hash({target_tracking_scaling_policy_configuration: {target_value: policy.target_tracking_scaling_policy_configuration.target_value} })
          cmp = policy.to_h
          cmp.delete(:alarms)
          cmp.delete(:creation_time)
          cmp.delete(:policy_arn)
          Dyna::Utils.normalize_hash(cmp)
        }.sort_by {|s| s[:scalable_dimension] }
      end

      def scaling_policies_eql?(dsl)
        scaling_policies_for_diff == dsl.scaling_policies.map { |policy| Dyna::Utils.normalize_hash(policy) }.sort_by {|s| s[:scalable_dimension] }
      end

      def definition_eql?(dsl)
        definition == dsl.definition
      end

      def provisioned_throughput_eql?(dsl)
        if definition[:billing_mode] == 'PROVISIONED' && billing_mode_eql?(dsl)
          return true
        end
        self_provisioned_throughput == dsl_provisioned_throughput(dsl)
      end

      def billing_mode_eql?(dsl)
        if definition[:billing_mode] == dsl[:billing_mode]
          return true
        end

        definition[:billing_mode].nil? && dsl[:billing_mode].to_s == 'PROVISIONED'
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
        dsl = dsl.dup
        unless dsl[:stream_specification]
          dsl[:stream_specification] = { stream_enabled: false }
        end

        log(:info, "  table: #{@table.table_name}(update stream spec)\n".green + Dyna::Utils.diff(self_stream_specification, dsl, :color => @options.color, :indent => '    '), false)
        unless @options.dry_run
          params = { table_name: @table.table_name }.merge(dsl)
          @ddb.update_table(params)
          @options.updated = true
        end
      end

      def update_table(dsl)
        params = {}
        df_params = {}
        unless billing_mode_eql?(dsl)
          params[:billing_mode] = dsl[:billing_mode]
          df_params[:billing_mode] = definition[:billing_mode]
        end

        if provisioned_throughput_eql?(dsl) == false && dsl[:scalable_targets].empty?
          params[:provisioned_throughput] = dsl[:provisioned_throughput].symbolize_keys
          df_params[:provisioned_throughput] = self_provisioned_throughput[:provisioned_throughput]
        end

        return if params.empty?
        log(:info, "  table: #{@table.table_name}\n".green + Dyna::Utils.diff(df_params, params, :color => @options.color, :indent => '    '), false)
        unless @options.dry_run
          wait_until_table_is_active
          params[:table_name] = @table.table_name
          @ddb.update_table(params.symbolize_keys)
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

      def update_auto_scaling(dsl)
        has_change = false
        unless scalable_targets_eql?(dsl)
          has_change = true
          df_cmp = definition[:scalable_targets].sort_by { |target| target[:scalable_dimension] }.map do |target|
            h = target.to_h
            h.delete(:creation_time)
            h.delete(:role_arn)
            Dyna::Utils.normalize_hash(h)
          end
          dsl_cmp = dsl.scalable_targets.sort_by { |target| target[:scalable_dimension] }.map { |target| Dyna::Utils.normalize_hash(target) }
          log(:info, "  table: #{@table.table_name}(update scalable targets)\n".green + Dyna::Utils.diff(df_cmp, dsl_cmp, :color => @options.color, :indent => '    '), false)
        end

        unless scaling_policies_eql?(dsl)
          has_change = true
          dsl_cmp = dsl.scaling_policies.map { |policy| Dyna::Utils.normalize_hash(policy) }.sort_by {|s| s[:scalable_dimension] }
          log(:info, "  table: #{@table.table_name}(update scaling policies)\n".green + Dyna::Utils.diff(scaling_policies_for_diff, dsl_cmp, :color => @options.color, :indent => '    '), false)
        end

        unless @options.dry_run
          if has_change
            definition[:scalable_targets].each do |target|
              @options.aas.deregister_scalable_target(
                service_namespace: 'dynamodb',
                resource_id: target.resource_id,
                scalable_dimension: target.scalable_dimension,
              )
            end

            dsl.scalable_targets.each do |target|
              @options.aas.register_scalable_target(target)
            end

            dsl.scaling_policies.each do |policy|
              @options.aas.put_scaling_policy(policy)
            end
          end
          @options.updated = true
        end
      end

      def update_time_to_live(dsl)
        params = { table_name: @table.table_name }
        if dsl.time_to_live_specification.enabled.to_s == 'true'
          params[:time_to_live_specification] = {
            enabled: dsl.time_to_live_specification.enabled,
            attribute_name: dsl.time_to_live_specification.attribute_name,
          }
        else
          params[:time_to_live_specification] = {
            enabled: false,
            attribute_name: aws_time_to_live.attribute_name,
          }
        end

        log(:info, "  table: #{@table.table_name}(update time to live)".green, false)
        log(:info, "    => enabled: #{params[:time_to_live_specification][:enabled]}".cyan, false)
        log(:info, "    => attribute_name: #{params[:time_to_live_specification][:attribute_name]}".cyan, false)

        unless @options.dry_run
          log(:debug, params, false)
          @ddb.update_time_to_live(params)
          @options.updated = true
        end
      end
    end
  end
end
