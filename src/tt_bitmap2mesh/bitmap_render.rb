#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/bitmap'


module TT::Plugins::BitmapToMesh
  class BitmapRender

    # attr_accessor :transformation
    attr_reader :transformation
    attr_reader :height

    # @param [Bitmap] dib
    def initialize(dib, max_sample_size = 64)
      @dib = dib
      @transformation = Geom::Transformation.new
      @cache = nil
      @bounds = nil
      @height = 0
      @samples = sample(@dib, max_sample_size)
    end

    def transformation=(value)
      @transformation = value
      @cache = nil
      @bounds = nil
    end

    def height=(value)
      if value != @height
        @height = value
        @cache = nil
        @bounds = nil
        # @samples = sample(@dib, max_sample_size)
      end
    end

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

    def compute_bounds
      max_point = Geom::Point3d.new(@dib.width, @dib.height, @height)
      max_point.transform!(@transformation)
      bounds = Geom::BoundingBox.new
      bounds.add(max_point)
      bounds
    end

    def compute_cache(samples)
      cached = {}
      samples.each { |color, quads|
        points = quads.flatten.map { |point| point.transform(@transformation) }
        cached[color] ||= []
        cached[color] = points
      }
      cached
    end

    def cache
      @cache ||= compute_cache(@samples)
      @cache
    end

    def sample(dib, max_sample_size)
      data = {}
      max_image_size = [dib.width, dib.height].max
      scale_down = max_sample_size.to_f / max_image_size.to_f
      scaled_width = (dib.width * scale_down).round
      scaled_height = (dib.height * scale_down).round
      scale_up = 1.0 / scale_down
      scaled_width.times { |scaled_x|
        scaled_height.times { |scaled_y|
          x = (scaled_x * scale_up).round
          y = (scaled_y * scale_up).round
          color = dib[x, y]
          scaled_z = color_to_height(color)
          quad = quad_points(scaled_x, scaled_y, scaled_z)
          data[color] ||= []
          data[color] << quad
        }
      }
      data
    end

    def quad_points(x, y, z = 0)
      [
        Geom::Point3d.new(x,     y,     z),
        Geom::Point3d.new(x + 1, y,     z),
        Geom::Point3d.new(x + 1, y + 1, z),
        Geom::Point3d.new(x,     y + 1, z),
      ]
    end

    def color_to_height(color)
      color_to_grayscale(color) / 255.0
    end

    def color_to_grayscale(color)
      r, g, b = color.to_a
      if r == g && g == b
        average_color = r
      else
        # http://forums.sketchucation.com/viewtopic.php?t=12368#p88865
        average_color = (r * 0.3) + (g * 0.59) + (b * 0.11)
      end
      average_color
    end

  end # module
end # module
