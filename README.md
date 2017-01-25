# Dyna

Dyna is a tool to manage DynamoDB Table.

It defines the state of DynamoDB Table using DSL, and updates DynamoDB Table according to DSL.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dyna'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dyna

## Usage

```sh
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION='ap-northeast-1'
dyna -e -o Dynafile  # export DynamoDB Table
vi Dynafile
dyna -a --dry-run
dyna -a               # apply `Dyanfile` to DynamoDB
```

## Help

```
Usage: dyna [options]
    -p, --profile PROFILE_NAME
        --credentials-path PATH
    -k, --access-key ACCESS_KEY
    -s, --secret-key SECRET_KEY
    -r, --region REGION
    -a, --apply
    -f, --file FILE
    -n, --table_names TABLE_LIST
    -x, --exclude_table_names TABLE_LIST
        --dry-run
    -e, --export
    -o, --output FILE
        --split
        --no-color
        --debug
```

## Dynafile example

```ruby
require 'other/groupfile'

dynamo_db "ap-northeast-1" do
  table "test_table" do
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

    stream_specification(
      stream_enabled: true,
      stream_view_type: "NEW_AND_OLD_IMAGES",
    )
 end
```

## Similar tools

* [Codenize.tools](http://codenize.tools/)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wata-gh/dyna.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
