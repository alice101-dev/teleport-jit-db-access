require "fluent/plugin/filter"
require "set"

module Fluent
  module Plugin
    # Passes each record only the first time its key is seen. Keys are kept in
    # a file, because the Teleport event handler resends the day's events on
    # every restart.
    class OnceFilter < Filter
      Fluent::Plugin.register_filter("once", self)

      desc "Record field that identifies the event"
      config_param :key, :string
      desc "File that remembers the keys already passed"
      config_param :path, :string

      def start
        super
        @seen = File.exist?(@path) ? Set.new(File.readlines(@path, chomp: true)) : Set.new
        @file = File.open(@path, "a")
        @file.sync = true
      end

      def shutdown
        @file&.close
        super
      end

      def filter(_tag, _time, record)
        id = record[@key].to_s
        return record if id.empty?
        return nil unless @seen.add?(id)

        @file.puts(id)
        record
      end
    end
  end
end
