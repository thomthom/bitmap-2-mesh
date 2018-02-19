#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/draggable'
require 'tt_bitmap2mesh/text'


module TT::Plugins::BitmapToMesh
  class Leader

    include Draggable

    attr_accessor :position

    def initialize(text)
      super()
      @text = Text.new(text)
      @text.align = TextAlignCenter
      @position = ORIGIN.clone
      @debug = true
    end

    def text
      @text.text
    end

    def text=(value)
      @text.text = value
    end

    def position
      @position
    end

    def position=(value)
      @position = value
    end

    def draw(view)
      @text.position = view.screen_coords(@position)
      @text.draw(view)
      if @debug
        view.drawing_color = Sketchup::Color.new(255, 0, 0, 64)
        view.draw2d(GL_QUADS, bounds(view))
      end
    end

    private

    def mouse_over?(x, y, view)
      Geom.point_in_polygon_2D([x, y, 0], bounds(view), true)
    end

    def bounds(view)
      height = 10 * 2 # Text height + line height
      width = @text.size * 10 * 0.85 # Arbitrary scaling for non-fixed width fonts
      h1 = height * 0.1
      h2 = height * 0.9
      w = width / 2.0
      x, y = view.screen_coords(@position).to_a
      [
        Geom::Point3d.new(x - w, y - h1, 0),
        Geom::Point3d.new(x + w, y - h1, 0),
        Geom::Point3d.new(x + w, y + h2, 0),
        Geom::Point3d.new(x - w, y + h2, 0),
      ]
    end

  end # class
end # module
