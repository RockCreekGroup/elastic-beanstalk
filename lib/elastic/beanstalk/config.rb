require 'singleton'
require 'dry/config'

module Elastic
  module Beanstalk
#
# EbConfig allows for default settings and mounting a specific environment with overriding
#   hash values and merging of array values.
#
#   NOTE: Anything can be overridden and merged into top-level settings (hashes) including
#   anything that is an array value.  Array values are merged *not* replaced.  If you think
#   something is screwy, see the defaults in the #init as those add some default array values.
#   If this behavior of merging arrays or the defaults are somehow un-sensible, file an issue and we'll revisit it.
#
    class Config < Dry::Config::Base

      include Singleton
      # it's a singleton, thus implemented as a self-extended module
      # extend self

      def initialize(options = {})
        # seed the sensible defaults here
        options = {
            symbolize: true,
            interpolation: false,
            default_configuration: {
                environment: nil,
                secrets_dir: '~/.aws',
                disallow_environments: %w(cucumber test),
                strategy: :blue_green,
                package: {
                    dir: 'pkg',
                    verbose: false,
                    includes: %w(**/* .ebextensions/**/*),
                    exclude_files: [],
                    exclude_dirs: %w(pkg tmp log test-reports)
                },
                options: {},
                inactive: {}
            }
        }.merge(options)
        super(options)
      end


      def load!(environment = nil, filename = resolve_path('config/eb.yml'))
        super(environment, filename)
      end


      def resolve_path(relative_path)
        if defined?(Rails)
          Rails.root.join(relative_path)
        elsif defined?(Rake.original_dir)
          File.expand_path(relative_path, Rake.original_dir)
        else
          File.expand_path(relative_path, Dir.pwd)
        end
      end

      # custom methods for the specifics of eb.yml settings
      def option_settings
        generate_settings(options)
      end

      def inactive_settings
        generate_settings(inactive)
      end

      def set_option(namespace, option_name, value)
        current_options = to_option_setting(namespace, option_name, value)
        namespace = current_options[:namespace].to_sym
        option_name = current_options[:option_name].to_sym

        options[namespace] = {} if options[namespace].nil?
        options[namespace][option_name] = value
      end

      def find_option_setting(name)
        find_setting(name, options)
      end

      def find_option_setting_value(name)
        find_setting_value(name, options)
      end

      def find_inactive_setting(name)
        find_setting(name, inactive)
      end

      def find_inactive_setting_value(name)
        find_setting_value(name, inactive)
      end

      def to_option_setting(namespace, option_name, value)
        erb_value = "#{value}".scan(/<%=.*%>/).first
        unless erb_value.nil?
          value = ERB.new(erb_value).result
        end
        {
            :'namespace' => "#{namespace}",
            :'option_name' => "#{option_name}",
            :'value' => "#{value}"
        }
      end

      private

      def find_setting(name, settings_root)
        name = name.to_sym
        settings_root.each_key do |namespace|
          settings_root[namespace].each do |option_name, value|
            if option_name.eql? name
              return to_option_setting(namespace, option_name, value)
            end
          end
        end
        return nil
      end

      def find_setting_value(name, settings_root)
        o = find_setting(name, settings_root)
        o[:value] unless o.nil?
      end

      def generate_settings(settings_root)
        result = []
        settings_root.each_key do |namespace|
          settings_root[namespace].each do |option_name, value|
            result << to_option_setting(namespace, option_name, value)
          end
        end

        #{"option_settings" => result}
        result
      end
    end
  end
end