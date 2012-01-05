module MCollective
  module Util
    module SchedHandler
      def initialize(msg); @msg = msg;  end
      def post_init; send_data(@msg); end
      def receive_data(response)
         $state=response
      end
      def unbind; EM.stop; end
    end
  end
end

