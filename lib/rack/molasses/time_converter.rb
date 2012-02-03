module Rack
  class Molasses
    class TimeConverter

      def self.to_seconds(str)
        return $1.to_i                    if str =~ /^(\d+)\s+(second|seconds)$/
        return $1.to_i * 60               if str =~ /^(\d+)\s+(minute|minutes)$/
        return $1.to_i * 3600             if str =~ /^(\d+)\s+(hour|hours)$/
        return $1.to_i * 3600 * 24        if str =~ /^(\d+)\s+(day|days)$/
        return $1.to_i * 3600 * 24 * 7    if str =~ /^(\d+)\s+(week|weeks)$/
        return $1.to_i * 3600 * 24 * 30   if str =~ /^(\d+)\s+(month|months)$/
        return $1.to_i * 3600 * 24 * 365  if str =~ /^(\d+)\s+(year|years)$/
        error_message = "The string '#{str}' is not formatted properly. "
        error_message << "Examples: '20 seconds' '4 minutes' '8 hours' '1 day' '8 weeks' '1 month' '1 year'."
        raise Rack::Molasses::Error.new(error_message)
      end

    end
  end
end
