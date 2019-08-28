if defined?(Rails)
  require 'rails/generators'
  require 'rails/generators/active_record'

  module Translateable
    class MigrationGenerator < ActiveRecord::Generators::Base
      desc 'Create sample migration with translateable field'
      source_root File.expand_path('templates', __dir__)

      argument :field_name, type: :string
      argument :locale, type: :string, default: I18n.default_locale

      def create_migration_file # rubocop: disable Metrics/AbcSize
        raise ArgumentError, "given locale #{locale} is not available, check I18n.available_locales" unless I18n.available_locales.include?(locale.to_sym)
        migration_template('migration.rb.erb', "db/migrate/migrate_translateable_#{table_name}_#{field_name}.rb", migration_version: migration_version)
      end

      private

      def rails4?
        Rails.version.start_with?('4')
      end

      def migration_version
        if rails4?
          ''
        else
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end
    end
  end
end
