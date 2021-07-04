# frozen_string_literal: true

require "rom/relation/name"

require "rom/components/dsl/relation"
require "rom/components/dsl/command"
require "rom/components/dsl/mapper"

module ROM
  # This extends Configuration class with the DSL methods
  #
  # @api public
  module Components
    module DSL
      # Relation definition DSL
      #
      # @example
      #   setup.relation(:users) do
      #     def names
      #       project(:name)
      #     end
      #   end
      #
      # @api public
      def relation(relation, **options, &block)
        dsl(DSL::Relation, relation: relation, block: block, **options).()
      end

      # Command definition DSL
      #
      # @example
      #   setup.commands(:users) do
      #     define(:create) do
      #       input NewUserParams
      #       result :one
      #     end
      #
      #     define(:update) do
      #       input UserParams
      #       result :many
      #     end
      #
      #     define(:delete) do
      #       result :many
      #     end
      #   end
      #
      # @api public
      def commands(relation, **options, &block)
        dsl(DSL::Command, relation: relation, block: block, **options).()
      end

      # Mapper definition DSL
      #
      # @api public
      def mappers(&block)
        dsl(DSL::Mapper, block: block).()
      end

      # Configures a plugin for a specific adapter to be enabled for all relations
      #
      # @example
      #   config = ROM::Configuration.new(:sql, 'sqlite::memory')
      #
      #   config.plugin(:sql, relations: :instrumentation) do |p|
      #     p.notifications = MyNotificationsBackend
      #   end
      #
      #   config.plugin(:sql, relations: :pagination)
      #
      # @param [Symbol] adapter The adapter identifier
      # @param [Hash<Symbol=>Symbol>] spec Component identifier => plugin identifier
      #
      # @return [Plugin]
      #
      # @api public
      def plugin(adapter, spec, &block)
        type, name = spec.flatten(1)

        # TODO: plugin types are singularized, so this is not consistent
        #       with the configuration DSL for plugins that uses plural
        #       names of the components - this should be unified
        plugin = ROM.plugin_registry[Inflector.singularize(type)].adapter(adapter).fetch(name)

        if block
          plugins << plugin.configure(&block)
        else
          plugins << plugin
        end
      end

      # @api private
      def infer_option(option, component:)
        if component.provider && component.provider != self
          component.provider.infer_option(option, component: component)
        elsif component.option?(:constant)
          # TODO: this could be transparent so that this conditional wouldn't be needed
          component.constant.infer_option(option, component: component)
        end
      end

      private

      # @api private
      def dsl(type, **options)
        type.new(**options, configuration: self)
      end
    end
  end
end
