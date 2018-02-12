#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/image/color'


module TT::Plugins::BitmapToMesh

  # @data must be a hash where the key is a colour and the values are array of
  # points. This way the image data is drawn in the most efficient manner using
  # the SketchUp API.
  class DIB

    attr_reader(:width, :height, :bitspp, :data)

    class Buffer < Array
      def <<(value)
        super(Color.new(value))
      end
    end

    # @overload initialize(filename)
    #   @param [String] filename
    #
    # @overload initialize(width, height, bitspp, color = 'white')
    #   @param [Integer] width
    #   @param [Integer] height
    #   @param [Integer] color
    def initialize(*args)
      case args.size
      when 1
        @data = read_image(args.first)
      when 3, 4
        @width, @height, @bitspp, color = args
        color ||= 'white'
        @data = Buffer.new(@width * @height, Color.new(color))
      else
        raise ArgumentError, 'wrong number of arguments'
      end
    end

    # @param [Integer] x
    # @param [Integer] y
    # @return [Color]
    def [](x, y)
      i = index(x, y)
      if i < 0 || i > @data.size
        raise IndexError, "index #{i} of #{@data.size} (#{x}, #{y})"
      end
      @data[i]
    end

    # @param [Integer] x
    # @param [Integer] y
    # @param [Color] color
    def []=(x, y, color)
      @data[index(x, y)] = Color.new(color)
    end

    # @param [Integer] index
    # @param [Color] color
    def set(index, color)
      @data[index] = Color.new(color)
    end

    # @return [Integer] Number of pixels.
    def pixels
      @width * @height
    end

    # @param [String] filename
    def save(filename)
      File.open(filename, 'wb') { |file|
        write_stream(file)
      }
    end

    private

    # @param [Integer] x
    # @param [Integer] y
    # @return [Integer]
    def index(x, y)
      (y * width) + x
    end

    # @param [String] filename
    # @return [Buffer]
    def read_image(filename)
      File.open(filename, 'rb') { |file|
        read_stream(file)
      }
    end

    # @param [IO] stream
    # @return [Buffer]
    def read_stream(stream) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError
    end

    # @param [IO] stream
    # @return [Buffer]
    def write_stream(stream) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError
    end

  end # class DIB

end # module
