require "dynamodb/stream/enumerator/version"
require "aws-sdk-dynamodbstreams"

module Dynamodb
  module Stream
    class Enumerator < ::Enumerator
      class Error < StandardError; end

      def initialize(stream_arn, client_or_options = {})
        @stream_arn = stream_arn
        @client = self.class.create_client(client_or_options)

        @throttle_on_empty_records = 1
        @record_batch_size = 1000
        @records = []

        super() do |yielder|
          loop do
            while @records.empty? do
              load_next_batch
            end

            yielder << @records.shift
          end
        end
      end

      def self.for_table(table_name, client_or_options = {})
        client = self.create_client(client_or_options)
        resp = client.list_streams({
          table_name: table_name,
          limit: 1
        })

        raise "More then one stream found" if resp.last_evaluated_stream_arn
        raise "No streams found" if resp.streams.empty?

        self.new(resp.streams[0].stream_arn, client)
      end

      private

      def self.create_client(client_or_options)
        if client_or_options.is_a?(Aws::DynamoDBStreams::Client)
          return client_or_options
        end

        Aws::DynamoDBStreams::Client.new(client_or_options)
      end

      def load_next_batch
        unless @shard_iterator
          get_next_shard
          get_shard_iterator
        end

        load_records

        # Throttle if no new records are available
        sleep @throttle_on_empty_records if @records.empty?
      end


      def load_records
        # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#get_records-instance_method
        resp = @client.get_records({
          shard_iterator: @shard_iterator,
          limit: @record_batch_size
        })

        @shard_iterator = resp.next_shard_iterator
        @records = resp.records
      end

      def get_next_shard
        last_evaluated_shard_id = nil
        next_shard = nil

        loop do
          # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#describe_stream-instance_method
          opts = {
            stream_arn: @stream_arn,
            limit: 100
          }
          opts[:exclusive_start_shard_id] = @last_evaluated_shard_id if @last_evaluated_shard_id

          resp = @client.describe_stream(opts)

          last_evaluated_shard_id = resp.stream_description.last_evaluated_shard_id
          shards = resp.stream_description.shards

          shards.each do |shard|
            # If we followed a shard previously, find the next one
            if @current_shard_id
              if shard.parent_shard_id == @current_shard_id
                next_shard = shard
                break
              else
                next
              end
            end

            # Shard without an ending sequence number contains the latest records
            unless shard.sequence_number_range.ending_sequence_number
              next_shard = shard
              break
            end
          end

          break if next_shard || !last_evaluated_shard_id
        end

        raise "Couldn't find next shard" unless next_shard

        @current_shard_id = next_shard.shard_id
      end

      def get_shard_iterator
        # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDBStreams/Client.html#get_shard_iterator-instance_method
        resp = @client.get_shard_iterator({
          shard_id: @current_shard_id,
          shard_iterator_type: "LATEST",
          stream_arn: @stream_arn,
        })

        @shard_iterator = resp.shard_iterator
      end
    end
  end
end
