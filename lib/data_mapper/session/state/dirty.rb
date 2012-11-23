module DataMapper
  class Session
    class State

      # Persistance state that is potentially dirty
      class Dirty < self
        include Equalizer.new(:identity, :tuple, :mapper, :object, :old)

        # Return old state
        #
        # @return [State]
        #
        # @api private
        #
        attr_reader :old

        # Test if object is dirty
        #
        # @return [true]
        #   if object is dirty
        #
        # @return [false]
        #   otherwise
        #
        # @api private
        #
        def clean?
          tuple == old.tuple
        end
        memoize :clean?

        # Persist changes to dirty object (if any)
        #
        # @return [State]
        #
        # @api private
        #
        def persist
          old = self.old

          return old if clean?

          mapper.update(self, old)

          Loaded.new(self)
        end

      private

        # Initialize object
        #
        # @param [Mapping] mapping
        # @param [State] old
        #
        # @return [undefined]
        #
        # @api private
        #
        def initialize(mapping, old)
          super(mapping)
          @old = old
        end

      end
    end
  end
end
