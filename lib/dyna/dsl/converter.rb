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
        stream_specification = ''
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

        if table[:stream_specification]
          stream_specification_tmpl = <<-EOS.chomp

    stream_specification(
      stream_enabled: <%= table[:stream_specification][:stream_enabled] %>,
      stream_view_type: <%= table[:stream_specification][:stream_view_type].inspect %>,
    )
EOS
          stream_specification = ERB.new(stream_specification_tmpl).result(binding)
        end

        if table[:scalable_targets]
          scalable_targets_tmpl = <<-EOS.chomp
<% table[:scalable_targets].each do |target| %>
    scalable_target(
      scalable_dimension: <%= target[:scalable_dimension].inspect %>,
      min_capacity: <%= target[:min_capacity] %>,
      max_capacity: <%= target[:max_capacity] %>,
    )
<% end %>
EOS
          scalable_targets = ERB.new(scalable_targets_tmpl).result(binding)
        end

        if table[:scaling_policies]
          scaling_policies_tmpl = <<-EOS.chomp
<% table[:scaling_policies].each do |policy| %>
    scaling_policy(
      scalable_dimension: <%= policy[:scalable_dimension].inspect %>,
      target_tracking_scaling_policy_configuration: {
        target_value: <%= policy[:target_tracking_scaling_policy_configuration][:target_value] %>,
      },
    )
<% end %>
EOS
          scaling_policies = ERB.new(scaling_policies_tmpl).result(binding)
        end

        <<-EOS
  table "#{name}" do
    key_schema(
      hash: #{table[:key_schema][0][:attribute_name].inspect},
      range: #{table[:key_schema].size == 1 ? 'nil' : table[:key_schema][1][:attribute_name].inspect},
    )
#{attribute_definitions}
    provisioned_throughput(
      read_capacity_units: #{table[:provisioned_throughput][:read_capacity_units]},
      write_capacity_units: #{table[:provisioned_throughput][:write_capacity_units]},
    )

    billing_mode #{table[:billing_mode].inspect}
#{local_secondary_indexes}#{global_secondary_indexes}#{stream_specification}#{scalable_targets}#{scaling_policies}
  end
        EOS
      end
    end
  end
end
