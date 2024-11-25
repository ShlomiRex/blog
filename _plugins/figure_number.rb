module Jekyll
    class FigureNumberTag < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
      end
  
      def render(context)
        # Initialize figure_number if it doesn't exist for this post
        context.registers[:page]['figure_number'] ||= 1
  
        # Increment figure_number
        context.registers[:page]['figure_number'] += 1
  
        # Return the current figure_number
        context.registers[:page]['figure_number'].to_s
      end
    end
  end
  
puts "Custom tag 'figure_number' loaded successfully."

Liquid::Template.register_tag('figure_number', Jekyll::FigureNumberTag)
  