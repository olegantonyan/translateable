require 'translateable/version'

module Translateable
  def self.included(base)
    base.extend ClassMethods
  end

  def self.translateable_attribute_by_name(attr)
    "#{attr}_translateable"
  end

  AttributeValue = Struct.new(:locale, :data)

  module ClassMethods
    def translateable(*attrs)
      attrs.each do |attr|
        translateable_sanity_check(attr)
        define_translateable_methods(attr)
      end
      define_translateable_strong_params(*attrs)
    end

    def translateable_sanity_check(attr)
      return if ENV['DISABLE_TRANSLATEABLE_SANITY_CHECK']
      return unless database_connection_exists?
      attr = attr.to_s
      raise ArgumentError, "no such column '#{attr}' in '#{name}' model" unless column_names.include?(attr)
    end

    def define_translateable_strong_params(*attrs)
      define_singleton_method('translateable_permitted_attributes') do
        attrs.each_with_object([]) { |i, obj| obj << { "#{i}_translateable_attributes" => %i(locale data _destroy) } }
      end
    end

    def database_connection_exists?
      ActiveRecord::Base.connection_pool.with_connection(&:active?)
    rescue StandardError
      false
    end

    def define_translateable_methods(attr)
      define_method("#{attr}_fetch_translateable") do
        value = self[attr]
        return value.with_indifferent_access if !value.nil? && !value.empty?
        (new_record? ? { I18n.locale => '' } : {}).with_indifferent_access
      end

      define_method(Translateable.translateable_attribute_by_name(attr)) do
        value = send("#{attr}_fetch_translateable")
        value.map { |k, v| AttributeValue.new(locale: k, data: v) }
      end

      define_method("#{attr}_translateable_attributes=") do |arg|
        self[attr] = arg.each_with_object({}) do |i, obj|
          hash = i.second
          next if hash[:_destroy]
          obj[hash[:locale]] = hash[:data]
        end
      end

      define_method(attr) do |**args|
        value = send("#{attr}_fetch_translateable")
        value[I18n.locale] || (value[I18n.default_locale] unless args[:strict]) || (value.values.first unless args[:strict])
      end

      define_method("#{attr}=") do |arg|
        value = arg.is_a?(Hash) ? arg : (self[attr] || {}).merge(I18n.locale => arg)
        self[attr] = value
      end
    end
  end
end
