require "dynamodb/stream/enumerator/version"
require "dynamodb/stream/enumerator/shard_reader"
require "aws-sdk-dynamodbstreams"

module Dynamodb
  module Stream
    class Enumerator < ::Enumerator
      class Error < StandardError; end

      def initialize(stream_arn, client: nil, client_options: {}, record_batch_size: 1000, throttle_on_empty_records: 1, on_ready: ->{})
        @stream_arn = stream_arn
        @client = client ? client : Aws::DynamoDBStreams::Client.new(client_options)

        @throttle_on_empty_records = throttle_on_empty_records
        @record_batch_size = record_batch_size
        @shard_readers = fetch_current_open_shards.map do |shard|
          shard_iterator = get_shard_iterator(shard, "LATEST")
          [shard, ShardReader.new(@client, shard_iterator)]
        end

        on_ready.call

        super() do |yielder|
          records = []
          loop do
            while records.empty? do
              records = load_next_batch
            end

            yielder << records.shift
          end
        end
      end

      private

      # Load next batch of records
      def load_next_batch
        next_shard_readers = []
        records = []

        until @shard_readers.empty?
          shard, shard_reader = @shard_readers.shift

          records = shard_reader.get_records(@record_batch_size)

          if shard_reader.finished?
            childs_shards = fetch_child_shards(shard)

            next_shard_readers.concat childs_shards.map do |shard|
              shard_iterator = get_shard_iterator(shard, "AT_SEQUENCE_NUMBER")
              [shard, ShardReader.new(@client, shard_iterator)]
            end
          else
            next_shard_readers << [shard, shard_reader]
          end

          break unless records.empty?
        end

        # Throttle if no new records are available in all shards
        sleep @throttle_on_empty_records if @shard_readers.empty?

        @shard_readers.concat(next_shard_readers)

        records
      end

      # Find all currently open shards
      def fetch_current_open_shards
        last_evaluated_shard_id = nil

        open_shards = []

        each_shard do |shard|
          # Shard without an ending sequence number contains the latest records
          open_shards << shard unless shard.sequence_number_range.ending_sequence_number
        end

        open_shards
      end

      # Find child shards
      def fetch_child_shards(shard)
        last_evaluated_shard_id = nil

        childs_shards = []

        each_shard do |potential_child_shard|
          childs_shards << potential_child_shard if potential_child_shard.parent_shard_id == shard.shard_id
        end

        childs_shards
      end

      # Iterate over all shards and yield each shard
      def each_shard
        # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#describe_stream-instance_method
        last_evaluated_shard_id = nil
        limit = 100
        loop do
          opts = {
            stream_arn: @stream_arn,
            limit: limit
          }
          opts[:exclusive_start_shard_id] = last_evaluated_shard_id if last_evaluated_shard_id

          resp = @client.describe_stream(opts)

          last_evaluated_shard_id = resp.stream_description.last_evaluated_shard_id

          shards = resp.stream_description.shards
          shards.each do |shard|
            yield shard
          end

          break if shards.length < limit
        end
      end

      def get_shard_iterator(shard, type)
        # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#get_shard_iterator-instance_method
        opts = {
          shard_id: shard.shard_id,
          shard_iterator_type: type,
          stream_arn: @stream_arn,
        }

        opts[:sequence_number] = shard.sequence_number_range.starting_sequence_number if type == "AT_SEQUENCE_NUMBER"

        resp = @client.get_shard_iterator(opts)

        resp.shard_iterator
      end
    end
  end
end
