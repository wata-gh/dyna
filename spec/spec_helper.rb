$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require 'dyna'
require 'pry-byebug'

RSpec.configure do |config|
  config.before(:each) {
    cleanup_dynamo
    @ddb_client = Aws::DynamoDB::Client.new
  }

  config.after(:all) do
    dynafile(:force => true) { '' }
  end
end

def wait_until_table_is_active(client, table_name)
  puts "waiting table #{table_name} to be ACTIVE or deleted.."
  loop do
    begin
      desc = describe_table(client, table_name)
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException => e
      break
    end
    status = desc.table_status
    puts "status... #{status}"
    break if desc.table_status == 'ACTIVE'
    sleep 3
  end
end

def wait_until_global_index_is_active(client, table_name)
  puts "waiting table #{table_name} GSI to be ACTIVE or deleted.."
  loop do
    begin
      desc = describe_table(client, table_name)
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException => e
      break
    end
    status = (desc.global_secondary_indexes || []).all? { |index| index.index_status == 'ACTIVE' }
    puts "status... #{status}"
    break if status
    sleep 3
  end
end

def cleanup_dynamo
  client = Aws::DynamoDB::Client.new
  client.list_tables.table_names.each do |table_name|
    wait_until_table_is_active(client, table_name)
    wait_until_global_index_is_active(client, table_name)
    client.delete_table(table_name: table_name)
    wait_until_table_is_active(client, table_name)
  end
end

def dynafile(options = {})
  updated = false
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }

    options = {
      :logger => Logger.new(debug? ? $stdout : '/dev/null'),
      :health_check_gc => true
    }.merge(options)

    client = Dyna::Client.new(options)
    updated = client.apply(tempfile)
  ensure
    FileUtils.rm_f(tempfile)
  end

  return updated
end

def fetch_table_list(client)
  client.list_tables.table_names
end

def describe_table(client, table_name)
  client.describe_table(table_name: table_name).table
end

def debug?
  ENV['DEBUG'] == '1'
end

