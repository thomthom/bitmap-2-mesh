#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
  class Text

    LEGACY_TEXT = Sketchup::View.instance_method(:draw_text).arity == 2

    attr_accessor :text, :position, :font, :size, :bold, :italic, :color, :align
    attr_accessor :outline_color

    def initialize(text)
      @text = text
      @position = ORIGIN.clone
      @color = Sketchup::Color.new('white')
      @outline_color = Sketchup::Color.new('black')
      @font = 'Arial'
      @size = 10
      @bold = true
      @italic = false
      @align = TextAlignRight
    end

    def draw(view)
      # draw_text(view, @position, @color)
      draw_outlined_text(view, @position, @color, @outline_color)
    end

    private

    def draw_outlined_text(view, position, color, outline_color)
      unless LEGACY_TEXT
        [
          Geom::Vector3d.new(-1, -1, 0),
          Geom::Vector3d.new(-1,  1, 0),
          Geom::Vector3d.new( 1, -1, 0),
          Geom::Vector3d.new( 1,  1, 0),
        ].each { |offset|
          pt = position.offset(offset)
          draw_text(view, pt, outline_color)
        }
      end
      draw_text(view, position, color)
    end

    def draw_text(view, position, color)
      if LEGACY_TEXT
        draw_text_legacy(view, position)
      else
        draw_text_new(view, position, color)
      end
    end

    def draw_text_new(view, position, color)
      options = {
        :font => @font,
        :size => @size,
        :bold => @bold,
        :italic => @italic,
        :color => color,
        :align => @align
      }
      view.draw_text(position, @text, options)
    end

    def draw_text_legacy(view, position)
      view.draw_text(position, @text)
    end

  end # class
end # module
