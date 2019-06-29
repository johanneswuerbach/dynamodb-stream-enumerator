require "aws-sdk-dynamodb"
require "aws-sdk-dynamodbstreams"

RSpec.describe Dynamodb::Stream::Enumerator do
  table_name = "dynamodb-stream-enumerator-test-#{Time.now.to_i}"

  before(:all) do
    @client = Aws::DynamoDB::Client.new
    @client.create_table({
      attribute_definitions: [{
        attribute_name: "Id",
        attribute_type: "S",
      }],
      table_name: table_name,
      key_schema: [
        {
          attribute_name: "Id",
          key_type: "HASH",
        },
      ],
      billing_mode: "PAY_PER_REQUEST",
      stream_specification: {
        stream_enabled: true,
        stream_view_type: "NEW_IMAGE",
      },
      sse_specification: {
        enabled: true
      },
      tags: [
        {
          key: "dynamodb-stream-enumerator",
          value: "ci",
        },
      ],
    })

    @client.wait_until(:table_exists, {
      table_name: table_name,
    })
  end

  after(:all) do
    @client.delete_table({
      table_name: table_name,
    })
  end

  it "has a version number" do
    expect(Dynamodb::Stream::Enumerator::VERSION).not_to be nil
  end

  it "does something useful" do
    found_records = []

    resp = @client.describe_table({
      table_name: table_name
    })

    enumerator_ready = false

    t = Thread.new do
      records = Dynamodb::Stream::Enumerator.new(resp.table.latest_stream_arn, on_ready: ->{ enumerator_ready = true })
      p "Start enumerator"
      records.each do |record|
        p "R: #{record}"
        found_records << record
      end
    end

    p "Waiting for enumerator"

    until enumerator_ready do; end

    p "Enumerator running"

    test_date = Time.now.iso8601

    resp = @client.put_item({
      item: {
        "Id" => "test",
        "Date" => test_date,
      },
      table_name: table_name
    })

    p "Item inserted, waiting"

    sleep 5

    t.exit

    expect(found_records.length).to be 1

    record = found_records[0]
    expect(record.event_name).to eq "INSERT"
    expect(record.dynamodb.new_image["Id"].s).to eq "test"
    expect(record.dynamodb.new_image["Date"].s).to eq test_date
  end
end
