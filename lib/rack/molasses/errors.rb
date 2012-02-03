module Rack
  class Molasses
    class Error < StandardError
      def initialize(msg=nil)
        msg = "Rack::Molasses Error: #{msg}"
        super
      end
    end
  end
end
