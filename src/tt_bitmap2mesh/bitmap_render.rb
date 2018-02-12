#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/bitmap'


module TT::Plugins::BitmapToMesh
  class BitmapRender

    attr_reader :transformation
    attr_reader :height

    # @param [Bitmap] bitmap
    def initialize(bitmap, max_sample_size = 64)
      @bitmap = bitmap
      @transformation = Geom::Transformation.new
      @cache = nil
      @bounds = nil
      @height = 0
      @samples = sample(@bitmap, max_sample_size)
    end

    # @param [Geom::Transformation] value
    def transformation=(value)
      @transformation = value
      @cache = nil
      @bounds = nil
    end

    # @param [Length] value
    def height=(value)
      if value != @height
        @height = value
        @cache = nil
        @bounds = nil
        # @samples = sample(@bitmap, max_sample_size)
      end
    end

    # @return [Geom::BoundingBox]
    def bounds
      @bounds ||= compute_bounds
      @bounds
    end

    # @param [Sketchup::View] view
    def draw(view)
      cache.each { |color, points|
        view.drawing_color = color
        view.draw(GL_QUADS, points)
      }
    end

    private

    # @return [Geom::BoundingBox]
    def compute_bounds
      max_point = Geom::Point3d.new(@bitmap.width, @bitmap.height, @height)
      max_point.transform!(@transformation)
      bounds = Geom::BoundingBox.new
      bounds.add(max_point)
      bounds
    end

    # @return [Hash{Color => Array<Geom::Point3d>}]
    def compute_cache(samples)
      cached = {}
      samples.each { |color, quads|
        points = quads.flatten.map { |point| point.transform(@transformation) }
        cached[color] ||= []
        cached[color] = points
      }
      cached
    end

    # @return [Hash{Color => Array<Geom::Point3d>}]
    def cache
      @cache ||= compute_cache(@samples)
      @cache
    end

    # @param [Bitmap] bitmap
    # @param [Integer] max_sample_size
    # @return [Hash{Color => Array<Geom::Point3d>}]
    def sample(bitmap, max_sample_size)
      data = {}
      max_image_size = [bitmap.width, bitmap.height].max
      scale_down = max_sample_size.to_f / max_image_size.to_f
      scaled_width = (bitmap.width * scale_down).round
      scaled_height = (bitmap.height * scale_down).round
      scale_up = 1.0 / scale_down
      scaled_width.times { |scaled_x|
        scaled_height.times { |scaled_y|
          x = (scaled_x * scale_up).round
          y = (scaled_y * scale_up).round
          color = bitmap[x, y]
          scaled_z = color_to_height(color)
          quad = quad_points(scaled_x, scaled_y, scaled_z)
          data[color] ||= []
          data[color] << quad
        }
      }
      data
    end

    # @return [Array(Geom::Point3d, Geom::Point3d, Geom::Point3d, Geom::Point3d)]
    def quad_points(x, y, z = 0)
      [
        Geom::Point3d.new(x,     y,     z),
        Geom::Point3d.new(x + 1, y,     z),
        Geom::Point3d.new(x + 1, y + 1, z),
        Geom::Point3d.new(x,     y + 1, z),
      ]
    end

    # @param [Color] color
    # @return [Float]
    def color_to_height(color)
      color.luminance / 255.0
    end

  end # module
end # module
