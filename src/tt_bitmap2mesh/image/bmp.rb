#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/image/dib'


module TT::Plugins::BitmapToMesh

  # Supported BMP variants:
  # * Bit-depths: 32bit, 24bit, 16bit, 8bit, 4bit, 1bit
  # * DIB Headers: OS2 v1, Windows v3
  # * Compression: BI_RGB (none)
  #
  # rubocop:disable Metrics/ClassLength
  class BMP < DIB

    # http://en.wikipedia.org/wiki/BMP_file_format
    #
    # http://www.herdsoft.com/ti/davincie/imex3j8i.htm
    # http://www.digicamsoft.com/bmp/bmp.html
    # http://netghost.narod.ru/gff/graphics/summary/os2bmp.htm
    # http://atlc.sourceforge.net/bmp.html#_toc381201084
    #
    # http://msdn.microsoft.com/en-us/library/dd183386%28VS.85%29.aspx
    # http://msdn.microsoft.com/en-us/library/dd183380%28VS.85%29.aspx
    # http://msdn.microsoft.com/en-us/library/dd183381%28VS.85%29.aspx
    #
    # http://entropymine.com/jason/bmpsuite/
    # http://wvnvaxa.wvnet.edu/vmswww/bmp.html
    #
    # uint32_t - DWORD - V
    # uint16_t -  WORD - v
    #
    # BMP File Header     Stores general information about the BMP file.
    # Bitmap Information  Stores detailed information about the bitmap image.
    #                     (DIB header)
    # Color Palette       Stores the definition of the colors being used for
    #                     indexed color bitmaps.
    # Bitmap Data         Stores the actual image, pixel by pixel.

    # Magic marker for BMP files.
    MAGIC_MARKER = 'BM'.freeze
    MAGIC_MARKER_WORD = MAGIC_MARKER.unpack('v').first

    # DIB Header Size
    BITMAPCOREHEADER  =  12 # OS/2 V1
    BITMAPCOREHEADER2 =  64 # OS/2 V2
    BITMAPINFOHEADER  =  40 # Windows V3
    BITMAPV4HEADER    = 108 # Windows V4
    BITMAPV5HEADER    = 124 # Windows V5

    # Compression
    BI_RGB       = 0
    BI_RLE8      = 1
    BI_RLE4      = 2
    BI_BITFIELDS = 3
    BI_JPEG      = 4
    BI_PNG       = 5

    private

    # @param [IO] stream
    # @return [Buffer]
    #
    # rubocop:disable Metrics/MethodLength, Style/TernaryParentheses,
    def read_stream(stream)
      # BMP File Header
      bmp_magic = stream.read(2)
      raise 'BMP Magic Marker not found.' if bmp_magic != MAGIC_MARKER
      _bmp_header = stream.read(12).unpack('VvvV')
      # filesz, reserved1, reserved2, bmp_offset = bmp_header

      # DIB Header
      # Read the first uint32_t that gives the size of the DIB header and use
      # that to determine which DIB header this BMP uses.
      compress_type = nil
      ncolors = nil
      width = nil
      height = nil
      # (!) Try to read V4 & V5 as BITMAPINFOHEADER. Seek to data start.
      header_sz = stream.read(4).unpack('V').first
      case header_sz
      when BITMAPCOREHEADER
        dib_header = stream.read(8).unpack('vvvv')
        width, height, _nplanes, bitspp = dib_header
      when BITMAPCOREHEADER2
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      when BITMAPINFOHEADER
        # (!) l to read signed 4 byte integer LE does not work on PPC Mac.
        # dib_header = stream.read(36).unpack('llvvVVllVV')
        dib_header = stream.read(36).unpack('VVvvVVVVVV')
        width, height, _nplanes, bitspp, compress_type, _bmp_bytesz,
            _hres, _vres, ncolors, _nimpcolors = dib_header
      when BITMAPV4HEADER
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      when BITMAPV5HEADER
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      else
        raise "Unknown DIB Header. (Size: #{header_sz})"
      end
      # TODO: @height might be negative in some cases. Store absolute value, but
      # ensure the rest of this method use the local variable height and not the
      # method accessor.
      @width = width
      @height = height
      @bitspp = bitspp

      # Verify the supported compression
      unless compress_type.nil? || compress_type == BI_RGB
        raise "Unsupported Compression Type. (type: #{compress_type})"
      end

      # Color Palette
      if bitspp < 16
        palette = []
        # Unless the DIB header specifies the colour count, use the max
        # palette size.
        if ncolors.nil? || ncolors == 0
          case bitspp
          when 1
            ncolors = 2
          when 4
            ncolors = 16
          when 8
            ncolors = 256
          else
            raise "Unknown Color Palette. #{bitspp}"
          end
        end
        ncolors.times {
          if header_sz == BITMAPCOREHEADER
            palette << stream.read(3).unpack('CCC').reverse!
          else
            b, g, r, _a = stream.read(4).unpack('CCCC')
            palette << [r, g, b] # TODO: Include alpha.
          end
        }
      end

      # Bitmap Data
      data = Buffer.new
      row = 0
      # row = y = x = 0
      # r, g, b, a, c, n = nil
      while row < height.abs
        # Row order is flipped if height is negative.
        # y = (height) < 0 ? row : height.abs - 1 - row
        x = 0
        while x < width.abs
          case bitspp
          when 1
            i = stream.read(1).unpack('C').first
            8.times { |bit|
              data << palette[(i & 0x80 == 0) ? 0 : 1]
              break if x + bit == width - 1
              i <<= 1
            }
            x += 7
          when 4
            i = stream.read(1).unpack('C').first
            data << palette[(i >> 4) & 0x0f]
            x += 1
            data << palette[i & 0x0f] if x < width
          when 8
            i = stream.read(1).unpack('C').first
            data << palette[i]
          when 16
            c = stream.read(2).unpack('v').first
            r = ((c >> 10) & 0x1f) << 3
            g = ((c >> 5)  & 0x1f) << 3
            b = (c >> 0x1f) << 3
            data << [r, g, b]
          when 24
            data << stream.read(3).unpack('CCC').reverse!
          when 32
            b, g, r, _a = stream.read(4).unpack('CCCC')
            data << [r, g, b] # TODO: Include alpha.
          else
            raise "UNKNOWN BIT DEPTH! #{bitspp}"
          end

          x += 1
        end
        # Skip trailing padding. Each row fills out to 32bit chunks
        row_size_to_32bit = ((@width * bitspp / 8) + 3) & ~3
        row_size_to_whole_bytes = (@width * bitspp / 8.0).ceil
        padding = row_size_to_32bit - row_size_to_whole_bytes
        stream.seek(padding, IO::SEEK_CUR)

        row += 1
      end
      data
    end

    BMP_HEADER_SIZE = 2 + 4 + 2 + 2 + 4

    # TODO: Currently saves OS/2 24bit BMPs only - no palette.
    # @param [IO] stream
    def write_stream(stream)
      # DIB Header
      dib_header = [
        4 + 2 + 2 + 2 + 2, # bcSize
        @width,            # bcWidth
        @height,           # bcHeight
        1,                 # bcPlanes
        @bitspp            # bcBitCount
      ].pack('Vvvvv')

      # Color Palette
      if bitspp < 16
        raise NotImplementedError, 'No palettes supported'
      end

      # Pixel Array
      row_size = ((@bitspp * @width + 31) / 32) * 4
      row_pixel_size = @width * 3
      row_padding = Array.new(row_size - row_pixel_size, 0)
      pixels = []
      @height.times { |y|
        @width.times { |x|
          color = self[x, y]
          bgr = color.to_a[0..2].reverse!
          pixels.concat(bgr)
        }
        pixels.concat(row_padding)
      }
      pixel_array = pixels.pack('C*')

      # BMP File Header
      filesize = BMP_HEADER_SIZE + dib_header.size + pixel_array.size
      bmp_file_header = [
          MAGIC_MARKER_WORD, # bfType
          filesize,          # bfSize
          0,                 # bfReserved1
          0,                 # bfReserved2
          BMP_HEADER_SIZE + dib_header.size # bfOffBits
      ].flatten.pack('vVvvV')

      stream.write(bmp_file_header)
      stream.write(dib_header)
      stream.write(pixel_array)
    end

  end # class BMP

end # module
