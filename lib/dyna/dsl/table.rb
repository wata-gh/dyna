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
