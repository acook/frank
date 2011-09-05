require 'tilt'

module Frank

  # Scss template implementation. See:
  # http://haml.hamptoncatlin.com/
  #
  # Sass templates do not support object scopes, locals, or yield.
  class SassTemplate < Tilt::SassTemplate
    def prepare
      @engine = ::Sass::Engine.new(data, sass_options.merge(Frank.sass_options || {}).merge(:syntax => :sass))
    end
  end
  Tilt.register 'sass', SassTemplate

  # Scss template implementation. See:
  # http://haml.hamptoncatlin.com/
  #
  # Sass templates do not support object scopes, locals, or yield.
  class ScssTemplate < Tilt::SassTemplate
    def prepare
      @engine = ::Sass::Engine.new(data, sass_options.merge(Frank.sass_options || {}).merge(:syntax => :scss))
    end
  end
  Tilt.register 'scss', ScssTemplate

  # Haml template implementation. See:
  # http://haml.hamptoncatlin.com/
  class HamlTemplate < Tilt::HamlTemplate
    def prepare
      options = @options.merge(:filename => eval_file, :line => line)
      @engine = ::Haml::Engine.new(data, options.merge(Frank.haml_options || {}))
    end
  end
  Tilt.register 'haml', HamlTemplate

  # Radius Template
  # http://github.com/jlong/radius/
  class RadiusTemplate < Tilt::Template
    def initialize_engine
      return if defined? ::Radius
      require_template_library 'radius'
    end

    def prepare
      @context = Class.new(Radius::Context).new
    end

    def evaluate(scope, locals, &block)
      @context.define_tag("yield") do
        block.call
      end
      (class << @context; self; end).class_eval do
        define_method :tag_missing do |tag, attr, &block|
          if locals.key?(tag.to_sym)
            locals[tag.to_sym]
          else
            scope.__send__(tag)  # any way to support attr as args?
          end
        end
      end
      # TODO: how to config tag prefix?
      parser = Radius::Parser.new(@context, :tag_prefix => 'r')
      parser.parse(data)
    end
  end
  Tilt.register 'radius', RadiusTemplate

  # Mustache template implementation. See:
  # http://mustache.github.com and https://github.com/acook/tilt-mustache
  class MustacheTemplate < Tilt::MustacheTemplate
    def prepare
      ::Mustache.template_path = file.gsub(File.basename(file), '') if file
      @engine = ::Mustache.new
      @output = nil

    end

    def evaluate(scope, locals, &block)
      if data =~ /^(\s*---(.+)---\s*)/m
        yaml = $2.strip
        template = data.sub($1, '')

        YAML.each_document(yaml) do |front_matter|
          # allows partials to override locals defined higher up
          front_matter.delete_if { |key,value| locals.has_key?(key)}
          locals.merge!(front_matter)
        end
      else
        template = data
      end

      scope.instance_variables.each do |instance_variable|
        symbol = instance_variable.to_s.gsub('@','').to_sym

        if ! locals[symbol]
          locals[symbol] = scope.instance_variable_get(instance_variable)
        end
      end

      locals[:yield] = block.nil? ? '' : yield
      locals[:content] = locals[:yield]

      @output ||= ::Mustache.render(template, locals)
    end
  end
  Tilt.register 'mustache', MustacheTemplate

end
