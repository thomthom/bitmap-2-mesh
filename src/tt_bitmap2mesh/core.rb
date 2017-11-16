#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


require 'tt_bitmap2mesh/place_mesh_tool'


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'Bitmap to Mesh' )

module TT::Plugins::BitmapToMesh

  ### MENU & TOOLBARS ### --------------------------------------------------

  unless file_loaded?( __FILE__ )
    m = TT.menu('Draw')
    m.add_item('Mesh From Heightmap')  { self.bitmap_to_mesh_tool() }

    UI.add_context_menu_handler { |context_menu|
      sel = Sketchup.active_model.selection
      if sel.length == 1 && sel[0].is_a?( Sketchup::Image )
        context_menu.add_item('Mesh From Heightmap')  { self.heightmap_to_mesh }
        context_menu.add_item('Mesh From Bitmap')     { self.image_to_mesh }
      end
    }
  end


  ### MAIN SCRIPT ### ------------------------------------------------------


  def self.image_to_mesh
    temp_path = File.expand_path( TT::System.temp_path )
    temp_file = File.join( temp_path, 'TT_BMP2Mesh.bmp' )
    model = Sketchup.active_model
    image = model.selection[0]
    tw = Sketchup.create_texture_writer
    tw.load( image )
    tw.write( image, temp_file )
    dib = GL_BMP.new( temp_file )
    File.delete( temp_file )

    size_x = image.width / image.pixelwidth
    size_y = image.height / image.pixelheight
    model.start_operation('Mesh From Bitmap', true)
      g = model.active_entities.add_group
      g.description = 'Mesh from Bitmap'
      progress = TT::Progressbar.new( dib.pixels, 'Mesh from Bitmap' )
      g.transform!( self.image_transformation(image) )
      dib.height.times { |y|
        dib.width.times { |x|
          progress.next
          index = (dib.width * y) + x
          color = dib.data[index]
          # Generate a Point3d from pixel colour.
          #r,g,b = color
          left  = x * size_x
          top   = y * size_y
          pts = [
            [left,top,0],
            [left+size_x,top,0],
            [left+size_x,top+size_y,0],
            [left,top+size_y,0]
          ]
          # (!) Detect failed face creation (too small)
          face = g.entities.add_face( pts )
          face.reverse! unless face.normal.samedirection?( Z_AXIS )
          face.material = color
        }
      }
    model.commit_operation
  end


  # (!) Doesn't handle flipped images correctly.
  def self.image_transformation(image)
    origin = image.origin
    axes = image.normal.axes
    tr = Geom::Transformation.axes(ORIGIN, axes.x, axes.y, axes.z)
    tr = tr*Geom::Transformation.rotation(ORIGIN, Z_AXIS, image.zrotation)
    #tr = (tr*Geom::Transformation.scaling(ORIGIN, image.width/image.pixelwidth, image.height/image.pixelheight, 1)).to_a
    tr = (tr*Geom::Transformation.scaling(ORIGIN, 1, 1, 1)).to_a
    tr[12] = origin.x
    tr[13] = origin.y
    tr[14] = origin.z
    return Geom::Transformation.new(tr)
  end




  #def self.image_to_mesh
  def self.heightmap_to_mesh
    temp_path = File.expand_path( TT::System.temp_path )
    temp_file = File.join( temp_path, 'TT_BMP2Mesh.bmp' )
    model = Sketchup.active_model
    image = model.selection[0]
    tw = Sketchup.create_texture_writer
    tw.load( image )
    tw.write( image, temp_file )
    dib = GL_BMP.new( temp_file )
    File.delete( temp_file )
    Sketchup.active_model.tools.push_tool( PlaceMeshTool.new(dib, image) )
  end


  def self.bitmap_to_mesh_tool
    # Select file
    filename = UI.openpanel('Select BMP File', nil, '*.bmp')
    return if filename.nil?
    # Load data
    dib = GL_BMP.new( filename )
    # Make the user pick the position of the mesh.
    Sketchup.active_model.tools.push_tool( PlaceMeshTool.new(dib) )
  end


  # :data must be a hash where the key is a colour and the values are array of points. This way the
  # image data is drawn in the most efficient manner using the SketchUp API availible.
  module GL_DIB
    attr_accessor(:width, :height, :data)

    def initialize(filename)
      @data = read_image(filename)
    end

    def pixels
      @width * @height
    end

  end # module GL_DIB

  # Supported BMP variants:
  # * Bitdepths: 32bit, 24bit, 16bit, 8bit, 4bit, 1bit
  # * DIB Headers: OS2 v1, Windows v3
  # * Compression: BI_RGB (none)
  class GL_BMP
    include GL_DIB

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
    # Bitmap Information  Stores detailed information about the bitmap image. (DIB header)
    # Color Palette       Stores the definition of the colors being used for indexed color bitmaps.
    # Bitmap Data         Stores the actual image, pixel by pixel.

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

    # This method silently fails when encountering errors. The error message is sent to the
    # console.
    #
    # Returns array of each pixel ( Array<Point3d, color> )
    def read_image(filename)
      #puts "\nReading BMP: '#{File.basename(filename)}' ..."

      file = File.open(filename, 'rb')

      # BMP File Header
      bmp_magic = file.read(2)
      raise 'BMP Magic Marker not found.' if bmp_magic != 'BM'
      bmp_header = file.read(12).unpack('VvvV')
        filesz, creator1, creator2, bmp_offset = bmp_header


      # DIB Header
      # Read the first uint32_t that gives the size of the DIB header and use that to determine
      # which DIB header this BMP uses.
      #
      # (!) Try to read V4 & V5 as BITMAPINFOHEADER. Seek to data start.
      header_sz = file.read(4).unpack('V').first
      case header_sz
      when BITMAPCOREHEADER
        dib_header = file.read(8).unpack('vvvv')
          @width, @height, nplanes, bitspp = dib_header
      when BITMAPCOREHEADER2
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      when BITMAPINFOHEADER
        # (!) l to read signed 4 byte integer LE does not work on PPC Mac.
        #dib_header = file.read(36).unpack('llvvVVllVV')
        dib_header = file.read(36).unpack('VVvvVVVVVV') # work for the types bundles with the plugin
          @width, @height, nplanes, bitspp, compress_type, bmp_bytesz,
          hres, vres, ncolors, nimpcolors = dib_header
      when BITMAPV4HEADER
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      when BITMAPV5HEADER
        raise "Unsupported DIB Header. (Size: #{header_sz})"
      else
        raise "Unknown DIB Header. (Size: #{header_sz})"
      end
      #puts dib_header.inspect

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
        ncolors.times { |i|
          if header_sz == BITMAPCOREHEADER
            palette << file.read(3).unpack('CCC').reverse!
          else
            b,g,r,a = file.read(4).unpack('CCCC')
            palette << [r,g,b]
          end
        }
        #puts palette.inspect
      end

      # Bitmap Data
      #data = Hash.new { |hash, key| hash[key] = [] }
      data = []
      row = y = x = 0
      r, g, b, a, c, n = nil
      while row < @height.abs
        # Row order is flipped if @height is negative.
        y = (@height < 0) ? row : @height.abs-1-row
        x = 0
        while x < @width.abs
          case bitspp
          when 1
            i = file.read(1).unpack('C').first
            8.times { |n|
              #data[ palette[(i & 0x80 == 0) ? 0 : 1] ] << Geom::Point3d.new(x+n,y,0)
              data << palette[(i & 0x80 == 0) ? 0 : 1]
              break if x+n == @width-1
              i <<= 1
            }
            x += 7
          when 4
            i = file.read(1).unpack('C').first
            #data[ palette[(i>>4) & 0x0f] ] << Geom::Point3d.new(x,y,0)
            data << palette[(i>>4) & 0x0f]
            x += 1
            #data[ palette[i & 0x0f] ] << Geom::Point3d.new(x,y,0) if x < @width
            data << palette[i & 0x0f] if x < @width
          when 8
            i = file.read(1).unpack('C').first
            #data[ palette[i] ] << Geom::Point3d.new(x,y,0)
            data << palette[i]
          when 16
            c = file.read(2).unpack('v').first
            r = ((c >> 10) & 0x1f) << 3
            g = ((c >>  5) & 0x1f) << 3
            b = (c >> 0x1f) << 3
            #data[ [r,g,b] ] << Geom::Point3d.new(x,y,0)
            data << [r,g,b]
          when 24
            #data[ file.read(3).unpack('CCC').reverse! ] << Geom::Point3d.new(x,y,0)
            data << file.read(3).unpack('CCC').reverse!
          when 32
            b,g,r,a = file.read(4).unpack('CCCC')
            #data[ [r,g,b] ] << Geom::Point3d.new(x,y,0)
            data << [r,g,b]
          else
            raise "UNKNOWN BIT DEPTH! #{bitspp}"
          end

          x += 1
        end
        # Skip trailing padding. Each row fills out to 32bit chunks
        # RowSizeTo32bit - RowSizeToWholeByte
        file.seek( (((@width*bitspp / 8) + 3) & ~3) - (@width*bitspp / 8.0).ceil, IO::SEEK_CUR)

        row += 1
      end
      #puts "> EOF: #{file.eof?.inspect} - Pos: #{file.pos} / #{filesz}\n\n"
    rescue => e
      puts "Failed to read #{filename}"
      puts e.message
      puts e.backtrace
      #data = {}
      data = []
    ensure
      file.close
      return data
    end

  end # class GL_BMP


  ### DEBUG ### ------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::BitmapToMesh.reload
  #
  # @param [Boolean] tt_lib Reloads TT_Lib2 if +true+.
  #
  # @return [Integer] Number of files reloaded.
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?( PATH ) && File.exist?( PATH )
      x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
