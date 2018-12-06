module Dyna
  class DSL
    class DynamoDB
      class Table
        include Dyna::TemplateHelper
        attr_reader :result

        def initialize(context, table_name, &block)
          @table_name = table_name
          @context = context

          @result = Hashie::Mash.new({
            :table_name => table_name,
            :scalable_targets => [],
            :scaling_policies => [],
          })
          instance_eval(&block)
        end

        def key_schema(hash:, range: nil)
          @result.key_schema = [{
            attribute_name: hash,
            key_type: 'HASH',
          }]

          if range
            @result.key_schema << {
              attribute_name: range,
              key_type: 'RANGE',
            }
          end
        end

        def attribute_definition(attribute_name:, attribute_type:)
          @result.attribute_definitions ||= []
          @result.attribute_definitions << {
            attribute_name: attribute_name,
            attribute_type: attribute_type,
          }
        end

        def provisioned_throughput(read_capacity_units:, write_capacity_units:)
          @result.provisioned_throughput = {
            read_capacity_units: read_capacity_units,
            write_capacity_units: write_capacity_units,
          }
        end

        def stream_specification(stream_enabled:, stream_view_type: nil)
          @result.stream_specification = {
            stream_enabled: stream_enabled,
            stream_view_type: stream_view_type,
          }
        end

        def local_secondary_index(index_name, &block)
          @result.local_secondary_indexes ||= []
          index = LocalSecondaryIndex.new
          index.instance_eval(&block)
          @result.local_secondary_indexes << {
            index_name: index_name,
          }.merge(index.result.symbolize_keys)
        end

        def global_secondary_index(index_name, &block)
          @result.global_secondary_indexes ||= []
          index = GlobalSecondaryIndex.new
          index.instance_eval(&block)
          @result.global_secondary_indexes << {
            index_name: index_name,
          }.merge(index.result.symbolize_keys)
        end

        def billing_mode(billing_mode)
          @result.billing_mode = billing_mode
        end

        def scalable_target(scalable_dimension:, min_capacity:, max_capacity:)
          @result.scalable_targets << {
            service_namespace: 'dynamodb',
            scalable_dimension: scalable_dimension,
            resource_id: "table/#{@result.table_name}",
            min_capacity: min_capacity,
            max_capacity: max_capacity,
            role_arn: 'arn:aws:iam::214219211678:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable',
          }
        end

        def scaling_policy(scalable_dimension:, target_tracking_scaling_policy_configuration:)
          predefined_metric_type = 'DynamoDBWriteCapacityUtilization'
          if scalable_dimension == 'dynamodb:table:ReadCapacityUnits'
            predefined_metric_type = 'DynamoDBReadCapacityUtilization'
          end
          @result.scaling_policies << {
            policy_name: "#{predefined_metric_type}:table/#{@result.table_name}",
            policy_type: 'TargetTrackingScaling',
            resource_id: "table/#{@result.table_name}",
            scalable_dimension: scalable_dimension,
            service_namespace: 'dynamodb',
            target_tracking_scaling_policy_configuration: target_tracking_scaling_policy_configuration.merge(predefined_metric_specification: {predefined_metric_type: predefined_metric_type}),
          }
        end

        class LocalSecondaryIndex
          attr_accessor :result

          def initialize
            @result = Hashie::Mash.new
          end

          def key_schema(hash:, range: nil)
            @result.key_schema = [{
              attribute_name: hash,
              key_type: 'HASH',
            }]

            if range
              @result.key_schema << {
                attribute_name: range,
                key_type: 'RANGE',
              }
            end
          end

          def projection(projection_type:, non_key_attributes: nil)
            @result.projection = {
              projection_type: projection_type,
              non_key_attributes: non_key_attributes,
            }
          end
        end

        class GlobalSecondaryIndex < LocalSecondaryIndex
          def provisioned_throughput(read_capacity_units:, write_capacity_units:)
            @result.provisioned_throughput = {
              read_capacity_units: read_capacity_units,
              write_capacity_units: write_capacity_units,
            }
          end
        end
      end
    end
  end
end
