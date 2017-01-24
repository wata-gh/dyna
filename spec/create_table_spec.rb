require 'spec_helper'

describe Dyna::Client do
  let(:table_name) { 'test_table' }

  context 'create_table' do
    it 'should create table' do
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

      tables = fetch_table_list(@ddb_client)
      expect(tables.size).to eq(1)

      desc = describe_table(@ddb_client, tables.first)

      key_sche0 = desc.key_schema[0]
      key_sche1 = desc.key_schema[1]
      expect(key_sche0.attribute_name).to eq('ForumName')
      expect(key_sche0.key_type).to eq('HASH')
      expect(key_sche1.attribute_name).to eq('Subject')
      expect(key_sche1.key_type).to eq('RANGE')

      attr_def0 = desc.attribute_definitions[0]
      attr_def1 = desc.attribute_definitions[1]
      expect(attr_def0.attribute_name).to eq("ForumName")
      expect(attr_def0.attribute_type).to eq("S")
      expect(attr_def1.attribute_name).to eq("Subject")
      expect(attr_def1.attribute_type).to eq("S")

      prov_throu = desc.provisioned_throughput
      expect(prov_throu.read_capacity_units).to eq(1)
      expect(prov_throu.write_capacity_units).to eq(2)

      local_index = desc.local_secondary_indexes
      expect(local_index[0].key_schema[0].attribute_name).to eq('ForumName')
      expect(local_index[0].key_schema[0].key_type).to eq('HASH')
      expect(local_index[0].key_schema[1].attribute_name).to eq('Subject')
      expect(local_index[0].key_schema[1].key_type).to eq('RANGE')

      global_index = desc.global_secondary_indexes
      expect(global_index.size).to eq(1)
      expect(global_index[0].key_schema[0].attribute_name).to eq('ForumName')
      expect(global_index[0].key_schema[0].key_type).to eq('HASH')
      expect(global_index[0].key_schema[1].attribute_name).to eq('Subject')
      expect(global_index[0].key_schema[1].key_type).to eq('RANGE')
      prov_throu = global_index.first.provisioned_throughput
      expect(prov_throu.read_capacity_units).to eq(1)
      expect(prov_throu.write_capacity_units).to eq(2)

      stream_spec = desc.stream_specification
      expect(stream_spec).to be_nil

      wait_until_table_is_active(@ddb_client, table_name)
    end
  end
end
