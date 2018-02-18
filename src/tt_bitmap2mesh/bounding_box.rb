#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
  # This class is different from Geom::BoundingBox because it should represent
  # the orientation in model space.
  class BoundingBox

    BOTTOM_FRONT_LEFT  = 0
    BOTTOM_FRONT_RIGHT = 1
    BOTTOM_BACK_RIGHT  = 2
    BOTTOM_BACK_LEFT   = 3

    TOP_FRONT_LEFT  = 4
    TOP_FRONT_RIGHT = 5
    TOP_BACK_RIGHT  = 6
    TOP_BACK_LEFT   = 7

    attr_reader :points

    def initialize(points)
      unless [4, 8].include?(points.size)
        raise ArgumentError, "Expected 4 or 8 points (#{points.size} given)"
      end
      @points = points
    end


    def is_2d?
      @points.size == 4
    end

    def is_3d?
      @points.size == 8
    end


    def have_area?
      x_axis.valid? && y_axis.valid?
    end

    def have_volume?
      x_axis.valid? && y_axis.valid? && z_axis.valid?
    end


    def width
      x_axis.length
    end

    def height
      y_axis.length
    end

    def depth
      z_axis.length
    end


    def origin
      @points[BOTTOM_FRONT_LEFT]
    end


    def x_axis
      @points[BOTTOM_FRONT_LEFT].vector_to(@points[BOTTOM_FRONT_RIGHT])
    end

    def y_axis
      @points[BOTTOM_FRONT_LEFT].vector_to(@points[BOTTOM_BACK_LEFT])
    end

    def z_axis
      @points[BOTTOM_FRONT_LEFT].vector_to(@points[TOP_FRONT_LEFT])
    end


    def draw(view)
      view.draw(GL_LINE_LOOP, @points[0..3])
      if is_3d?
        view.draw(GL_LINE_LOOP, @points[4..7])
        connectors = [
          @points[0], @points[4],
          @points[1], @points[5],
          @points[2], @points[6],
          @points[3], @points[7]
        ]
        view.draw(GL_LINES, connectors)
      end
    end

  end # class
end # module
