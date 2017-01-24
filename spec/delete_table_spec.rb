require 'spec_helper'

describe Dyna::Client do
  let(:table_name) { 'test_table' }

  context 'delete_table' do
    it 'should delete table' do
      dynafile do
<<EOS
dynamo_db 'ap-northeast-1' do
  table '#{table_name}' do
    key_schema(
      hash: "ForumName",
      range: "Subject"
    )

    attribute_definition(
      attribute_name: "ForumName",
      attribute_type: "S",
    )
    attribute_definition(
      attribute_name: "Subject",
      attribute_type: "S",
    )

    provisioned_throughput(
      read_capacity_units: 1,
      write_capacity_units: 2,
    )

    local_secondary_index "LocalIndexName" do
      key_schema hash: "ForumName", range: "Subject"
      projection projection_type: 'ALL'
    end

    global_secondary_index "GlobalIndexName" do
      key_schema hash: "ForumName", range: "Subject"
      projection projection_type: 'ALL'
      provisioned_throughput read_capacity_units: 1, write_capacity_units: 2
    end

    stream_specification stream_enabled: false
   end
end
EOS
      end

      wait_until_table_is_active(@ddb_client, table_name)

      dynafile do
<<EOS
dynamo_db 'ap-northeast-1' do
end
EOS
      end

      wait_until_table_is_active(@ddb_client, table_name)
      expect { describe_table(@ddb_client, table_name) }.to raise_error(Aws::DynamoDB::Errors::ResourceNotFoundException)
    end
  end
end
