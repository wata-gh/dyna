module Dyna
  class DSL
    class Converter
      class << self
        def convert(region, exported)
          self.new(region, exported).convert
        end
      end

      def initialize(region, exported)
        @region = region
        @exported = exported
      end

      def convert
        output_dynamo_db
      end

      private
      def output_dynamo_db
        tables = @exported.map {|name, table|
          output_table(name, table)
        }.join("\n").strip

        <<-EOS
dynamo_db "#{@region}" do
  #{tables}
end
        EOS
      end

      def output_table(name, table)
        local_secondary_indexes = ''
        global_secondary_indexes = ''
        if table[:local_secondary_indexes]
          local_secondary_indexes_tmpl = <<-EOS.chomp
<% table[:local_secondary_indexes].each do |index| %>
    local_secondary_index <%= index[:index_name].inspect %> do
      key_schema hash: <%= index[:key_schema][0][:attribute_name].inspect %>, range: <%= index[:key_schema][1][:attribute_name].inspect %><% if index[:projection] %>
      projection projection_type: <%= index[:projection][:projection_type].inspect %><% end %>
    end
<% end %>
EOS
          local_secondary_indexes = ERB.new(local_secondary_indexes_tmpl).result(binding)
        end

        if table[:global_secondary_indexes]
          global_secondary_indexes_tmpl = <<-EOS.chomp
<% table[:global_secondary_indexes].each do |index| %>
    global_secondary_index <%= index[:index_name].inspect %> do
      key_schema hash: <%= index[:key_schema][0][:attribute_name].inspect %><% if index[:key_schema].size == 2 %>, range: <%= index[:key_schema][1][:attribute_name].inspect %><% end %><% if index[:projection] %>
      projection projection_type: <%= index[:projection][:projection_type].inspect %><% end %>
      provisioned_throughput read_capacity_units: <%= index[:provisioned_throughput][:read_capacity_units] %>, write_capacity_units: <%= index[:provisioned_throughput][:read_capacity_units] %>
    end
<% end %>
EOS
          global_secondary_indexes = ERB.new(global_secondary_indexes_tmpl).result(binding)
        end

        attribute_definitions_tmpl = <<-EOS.chomp
<% table[:attribute_definitions].each do |attr| %>
    attribute_definition(
      attribute_name: <%= attr[:attribute_name].inspect %>,
      attribute_type: <%= attr[:attribute_type].inspect %>,
    )
<% end %>
EOS
        attribute_definitions = ERB.new(attribute_definitions_tmpl).result(binding)
        <<-EOS
  table "#{name}" do
    key_schema(
      hash: #{table[:key_schema][0][:attribute_name].inspect},
      range: #{table[:key_schema][1][:attribute_name].inspect},
    )
#{attribute_definitions}
    provisioned_throughput(
      read_capacity_units: #{table[:provisioned_throughput][:read_capacity_units]},
      write_capacity_units: #{table[:provisioned_throughput][:write_capacity_units]},
    )
#{local_secondary_indexes}#{global_secondary_indexes}
  end
        EOS
      end
    end
  end
end
