module Concurrent
  module Actor
    module Behaviour
      class Supervising < Abstract
        def initialize(core, subsequent, handle, strategy)
          super core, subsequent
          @handle   = Match! handle, :terminate!, :resume!, :reset!, :restart!
          @strategy = case @handle
                      when :terminate!
                        Match! strategy, nil
                      when :resume!
                        Match! strategy, :one_for_one
                      when :reset!, :restart!
                        Match! strategy, :one_for_one, :one_for_all
                      end
        end

        def on_envelope(envelope)
          case envelope.message
          when Exception, :paused
            receivers = if @strategy == :one_for_all
                          children
                        else
                          [envelope.sender]
                        end
            receivers.each { |ch| ch << @handle }
          else
            pass envelope
          end
        end
      end
    end
  end
end
