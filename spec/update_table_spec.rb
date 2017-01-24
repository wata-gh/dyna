require 'spec_helper'

describe Dyna::Client do
  let(:table_name) { 'test_table' }

  context 'update_table' do
    it 'should update table attributes' do
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
  table 'test_table' do
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
      read_capacity_units: 2,
      write_capacity_units: 1,
    )

    local_secondary_index "LocalIndexName" do
      key_schema hash: "ForumName", range: "Subject"
      projection projection_type: 'ALL'
    end

    global_secondary_index "GlobalIndexName" do
      key_schema hash: "ForumName", range: "Subject"
      projection projection_type: 'ALL'
      provisioned_throughput read_capacity_units: 3, write_capacity_units: 4
    end

    stream_specification stream_enabled: true, stream_view_type: 'KEYS_ONLY'
   end
end
EOS
      end

      wait_until_table_is_active(@ddb_client, table_name)
      wait_until_global_index_is_active(@ddb_client, table_name, 'GlobalIndexName')

      desc = describe_table(@ddb_client, table_name)

      prov_throu = desc.provisioned_throughput
      expect(prov_throu.read_capacity_units).to eq(2)
      expect(prov_throu.write_capacity_units).to eq(1)

      global_index = desc.global_secondary_indexes
      expect(global_index.size).to eq(1)
      prov_throu = global_index.first.provisioned_throughput
      expect(prov_throu.read_capacity_units).to eq(3)
      expect(prov_throu.write_capacity_units).to eq(4)

      stream_spec = desc.stream_specification
      expect(stream_spec.stream_enabled).to be(true)
      expect(stream_spec.stream_view_type).to eq('KEYS_ONLY')
    end
  end
end
