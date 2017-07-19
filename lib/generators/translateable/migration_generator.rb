if defined?(Rails)
  require 'rails/generators'
  require 'rails/generators/active_record'

  module Translateable
    class MigrationGenerator < ActiveRecord::Generators::Base
      desc 'Create sample migration with translateable field'
      source_root File.expand_path('../templates', __FILE__)

      argument :field_name, type: :string
      argument :locale, type: :string, default: I18n.default_locale

      def create_migration_file
        raise ArgumentError, "given locale #{locale} is not available, check I18n.available_locales" unless I18n.available_locales.include?(locale.to_sym)
        migration_template('migration.rb.erb', "db/migrate/migrate_translateable_#{name}_#{field_name}.rb",
                           migration_version: migration_version,
                           table_name: name,
                           field_name: field_name,
                           field_type: name.classify.constantize.columns_hash[field_name].type,
                           locale: locale)
      end

      private

      def rails5?
        Rails.version.start_with?('5')
      end

      def migration_version
        if rails5?
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        else
          ''
        end
      end
    end
  end
end
