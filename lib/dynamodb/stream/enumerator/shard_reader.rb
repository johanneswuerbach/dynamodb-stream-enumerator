require "dynamodb/stream/enumerator/version"
require "aws-sdk-dynamodbstreams"

module Dynamodb
  module Stream
    class Enumerator < ::Enumerator
      class ShardReader
        def initialize(client, shard_iterator)
          @client = client
          @shard_iterator = shard_iterator
        end

        def finished?
          @shard_iterator.nil?
        end

        def get_records(limit)
          # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#get_records-instance_method
          resp = @client.get_records({
            shard_iterator: @shard_iterator,
            limit: limit
          })

          @shard_iterator = resp.next_shard_iterator

          resp.records
        end
      end
    end
  end
end
