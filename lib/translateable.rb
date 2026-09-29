require 'translateable/version'

module Translateable
  def self.included(base)
    base.extend ClassMethods
  end

  def self.translateable_attribute_by_name(attr)
    "#{attr}_translateable"
  end

  AttributeValue = Struct.new(:locale, :data, keyword_init: true) do
    def _destroy; end

    def persisted?
      false
    end
  end

  module ClassMethods
    def translateable(*attrs, sanity_checks: true)
      attrs.each do |attr|
        translateable_sanity_check(attr) if sanity_checks
        define_translateable_methods(attr)
      end
      @translateable_attributes = (@translateable_attributes || []) | attrs
    end

    def translateable_attributes
      inherited = superclass.respond_to?(:translateable_attributes) ? superclass.translateable_attributes : []
      inherited | (@translateable_attributes || [])
    end

    def translateable_permitted_attributes
      translateable_attributes.map { |attr| { "#{attr}_translateable_attributes" => %i(locale data _destroy) } }
    end

    def translateable_sanity_check(attr)
      return if ENV['DISABLE_TRANSLATEABLE_SANITY_CHECK']
      return unless database_connection_exists? && table_exists?
      attr = attr.to_s
      raise ArgumentError, "no such column '#{attr}' in '#{name}' model" unless column_names.include?(attr)
    end

    def database_connection_exists?
      connection_pool.with_connection(&:active?)
    rescue StandardError
      false
    end

    def define_translateable_methods(attr)
      define_method("#{attr}_fetch_translateable") do
        (self[attr] || {}).with_indifferent_access
      end

      define_method(Translateable.translateable_attribute_by_name(attr)) do
        value = send("#{attr}_fetch_translateable")
        value = { I18n.locale.to_s => '' } if value.empty? && new_record?
        value.map { |k, v| AttributeValue.new(locale: k, data: v) }
      end

      define_method("#{attr}_translateable_attributes=") do |arg|
        entries = arg.respond_to?(:values) ? arg.values : arg
        self[attr] = entries.each_with_object({}) do |entry, obj|
          entry = entry.with_indifferent_access if entry.is_a?(Hash)
          next if ActiveModel::Type::Boolean.new.cast(entry[:_destroy])
          obj[entry[:locale].to_s] = entry[:data]
        end
      end

      define_method(attr) do |**args|
        value = send("#{attr}_fetch_translateable")
        value[I18n.locale] || (value[I18n.default_locale] unless args[:strict]) || (value.values.first unless args[:strict])
      end

      define_method("#{attr}=") do |arg|
        self[attr] = arg.respond_to?(:to_hash) ? arg.to_hash : (self[attr] || {}).merge(I18n.locale.to_s => arg)
      end

      # Rails form helpers read <attr>_before_type_cast for user-assigned values, e.g. when
      # re-rendering a form after a failed validation. Without this they would show the raw
      # JSONB hash instead of the current locale's text (#10).
      define_method("#{attr}_before_type_cast") do
        send(attr)
      end
    end
  end
end
