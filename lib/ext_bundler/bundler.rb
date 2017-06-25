module Bundler
  class << self
    attr_accessor :sourced_gems, :sourced_gems_computed

    module WithSource
      def gemfile_urls
        @_gemfile_urls ||= root.join('Gemfile.urls')
      end

      def definition(unlock = nil)
        super

        unless sourced_gems_computed || !sourced_gems
          @definition = Definition.build(default_gemfile, default_lockfile, unlock)
          self.sourced_gems_computed = true
        end

        @definition
      end

      def default_gemfile
        @_default_gemfile ||= begin
          default_file = super
          if ARGV[0] == 'update' && File.exist?(gemfile_urls)
            update_file = root.join('.bundle/ext_bundler_update')
            FileUtils.copy(default_file, update_file)
            File.open(update_file, 'a') do |f|
              File.readlines(gemfile_urls).each do |line|
                f.puts line
              end
            end
            default_file = update_file
          end
          default_file
        end
      end
    end
    prepend WithSource
  end

  Dsl.class_eval do
    class << self
      module WithSource
        def evaluate(gemfile, lockfile, unlock)
          return super unless (paths = Bundler.sourced_gems)

          File.open(Bundler.gemfile_urls, "w") do |f|
            paths.each do |name, options|
              options = options.each_with_object([]) do |(key, value), memo|
                memo << "#{key}: '#{value}'"
              end
              f.puts("gem '#{name}', #{options.join(', ')}")
            end
          end
          builder = new
          builder.eval_gemfile(gemfile)
          builder.eval_gemfile(Bundler.gemfile_urls)
          builder.to_definition(lockfile, unlock)
        end
      end
      prepend WithSource
    end
  end
end

module Gem
  Specification.class_eval do
    module WithSource
      def add_dependency(gem, *requirements)
        options = requirements.last
        options = if options.is_a?(Hash) && options.instance_of?(Hash)
          requirements.pop
        else
          {}
        end

        if options.any?
          Bundler.sourced_gems ||= {}
          Bundler.sourced_gems[gem] = options
        end

        super
      end
    end
    prepend WithSource
  end
end

if Bundler::VERSION < '2.0'
  Bundler.settings["github.https"] = true
end
