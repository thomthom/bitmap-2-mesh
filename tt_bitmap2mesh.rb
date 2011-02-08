#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
# Copyright 2010
#
#-----------------------------------------------------------------------------
#
# CHANGELOG
# 0.4.0b - 08.02.2011
#		 * TT::Progressbar support.
#
# 0.3.0b - 21.12.2010
#		 * Renamed 'Mesh From Bitmap' to 'Mesh From Heightmap'
#		 * Added new 'Mesh From Bitmap'
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.0', 'TT BitmapToMesh')

#-----------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
  
  ### CONSTANTS ### --------------------------------------------------------
  
  VERSION = '0.4.0'
  
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
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

  
  class PlaceMeshTool
    
    S_START = 0
    S_RECT  = 1
    S_BOX   = 2
    
    def initialize( dib, image = nil )
      @dib = dib
      @ratio = dib.width.to_f / dib.height.to_f
      
      @ip_start = Sketchup::InputPoint.new
      @ip_rect  = Sketchup::InputPoint.new
      @ip_mouse = Sketchup::InputPoint.new
      
      @image = image
    end
    
    def enableVCB?
      true
    end
    
    def activate
      reset()
    end
    
    def reset
      @ip_start.clear
      @ip_rect.clear
      @ip_mouse.clear
      
      @ph = nil
      
      @state = S_START
      
      if @image
        @ip_start = Sketchup::InputPoint.new( @image.origin )
        pt = @image.origin.offset( @image.normal.axes.x, @image.width )
        pt.offset!( @image.normal.axes.y, @image.height )
        @ip_rect = Sketchup::InputPoint.new( pt )
        @state = S_BOX
      end
      
      update_ui()
    end
    
    def update_ui
      case @state
      when S_START
        Sketchup.status_text = 'Pick origin. Picking a point on a face will orient the mesh to the face.'
        Sketchup.vcb_label = ''
        Sketchup.vcb_value = ''
      when S_RECT
        Sketchup.status_text = 'Pick width.'
        Sketchup.vcb_label = 'Width:'
        pts = get_box()
        Sketchup.vcb_value = pts[0].distance( pts[1] )
      when S_BOX
        Sketchup.status_text = 'Pick depth.'
        Sketchup.vcb_label = 'Depth:'
        pts = get_box()
        Sketchup.vcb_value = pts[0].distance( pts[4] )
      end
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
    end
    
    def onCancel(reason, view)
      reset()
      view.invalidate
    end
    
    def onUserText(text, view)
      length = text.to_l
      return if length == 0
      case @state
      when S_RECT
        pts = get_box()
        vx = pts[0].vector_to( pts[1] )
        if vx.valid?
          pt = @ip_start.position.offset( vx, length )
          @ip_rect = Sketchup::InputPoint.new( pt )
          @state = S_BOX
        end
      when S_BOX
        pts = get_box()
        normal = pts[0].vector_to( pts[4] )
        unless normal.valid?
          vx = pts[0].vector_to( pts[1] )
          vy = pts[0].vector_to( pts[3] )
          normal = vx * vy
        end
        pt = @ip_start.position.offset( normal, length )
        @ip_mouse = Sketchup::InputPoint.new( pt )
        generate_mesh()
      end
      update_ui()
      view.invalidate
    end
    
    def onMouseMove(flags, x, y, view)
      @ip_mouse.pick(view, x, y)
      view.tooltip = @ip_mouse.tooltip
      #@ph = view.pick_helper( x, y )
      #@ph.do_pick( x, y )
      view.invalidate
      update_ui()
    end
    
    def onLButtonUp(flags, x, y, view)
      case @state
      when S_START
        #ph = view.pick_helper( x, y )
        #ph.do_pick( x, y )
        #bp = ph.best_picked
        #if bp.is_a?( Sketchup::Image )
        #  @image = bp
        #  reset()
        #else
          @ip_start.copy!(@ip_mouse)
          @state = S_RECT
        #end
      when S_RECT
        @ip_rect.copy!(@ip_mouse)
        @state = S_BOX
      when S_BOX
        generate_mesh()
      end
      view.invalidate
      update_ui()
    end
    
    def draw(view)
      @ip_mouse.draw(view) if @ip_mouse.valid?

      view.line_width = 2
      view.line_stipple = ''
      view.drawing_color = [255,0,0]
      
      box = get_box
      
      #if @state == S_START
      #  bp = @ph.best_picked
      #  if bp.is_a?( Sketchup::Image )
      #    axes = bp.normal.axes
      #    rect = []
      #    rect << bp.origin
      #    rect << rect.last.offset( axes.x, bp.width )
      #    rect << rect.last.offset( axes.y, bp.height )
      #    rect << rect.first.offset( axes.y, bp.height )
      #    view.draw( GL_LINE_LOOP, rect )
      #  end
      #end
      
      if @state == S_RECT || @state == S_BOX
        view.draw( GL_LINE_LOOP, box[0..3] )
      end
      
      if @state == S_BOX
        view.draw( GL_LINE_LOOP, box[4..7] )
        
        connectors = [
          box[0], box[4],
          box[1], box[5],
          box[2], box[6],
          box[3], box[7]
        ]
        view.draw( GL_LINES, connectors )
      end
    end
    
    def getExtents
      bb = Geom::BoundingBox.new
      pts = get_box()
      pts.each { |pt|
        bb.add( pt )
      }
      bb
    end
    
    def get_box
      pts = []
      if @state == S_RECT || @state == S_BOX
        if @image
          vx = @image.normal.axes.x
          vy = @image.normal.axes.y
          vz = @image.normal.axes.z
          plane = [ @image.origin, vz ]
        else
          face = @ip_start.face
          vx = (face) ? face.normal.axes.x : X_AXIS
          vy = (face) ? face.normal.axes.y : Y_AXIS
          vz = (face) ? face.normal.axes.z : Z_AXIS
          plane = (face) ? face.plane : [ORIGIN, Z_AXIS]
        end
        
        ip2 = (@state == S_RECT) ? @ip_mouse : @ip_rect
        
        pt1 = @ip_start.position
        pt2 = ip2.position.project_to_line( [pt1, vx] )
        width = pt1.distance( pt2 )
        height = width / @ratio
        pt3 = pt2.offset( vy, height )
        pt4 = pt1.offset( vy, height )
        
        rect_lower = [pt1, pt2, pt3, pt4]
        pts.concat( rect_lower )
      end
      
      if @state == S_BOX
        mp = @ip_mouse.position
        pt5 = mp.project_to_line( [pt1, vz] )
        depth = pt1.vector_to( pt5 )
        pt6 = pt2.offset( depth )
        pt7 = pt3.offset( depth )
        pt8 = pt4.offset( depth )
        
        rect_upper = [pt5, pt6, pt7, pt8]
        pts.concat( rect_upper )
      end
      pts
    end
    
    def generate_mesh
      box = get_box()
      xaxis = box[0].vector_to( box[1] )
      yaxis = box[0].vector_to( box[3] )
      zaxis = box[0].vector_to( box[4] )
      width  = xaxis.length
      height = yaxis.length
      depth  = zaxis.length
      origin = box[0]
      TT::Model.start_operation('Mesh From Heightmap')
      t = Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
      g = bitmap_to_mesh(@dib, width, height, depth)
      g.transformation = t
      Sketchup.active_model.commit_operation
      Sketchup.active_model.tools.pop_tool
    end
    
    def bitmap_to_mesh(dib, width, height, depth)
      model = Sketchup.active_model
      # Dimensions
      step_x = width  / dib.width
      step_y = height / dib.height
      step_z = depth  / 255
      # Process data
      puts 'Bitmap To Mesh:'
      start_time = Time.now
      # Read colour values and generate 3d points.
      pts = []
      progress = TT::Progressbar.new( dib.pixels, 'Reading Image' )
      dib.height.times { |y|
        dib.width.times { |x|
          progress.next
          index = (dib.width * y) + x
          color = dib.data[index]
          # Generate a Point3d from pixel colour.
          r,g,b = color
          if r == g && g == b
            average_color = r
          else
            # http://forums.sketchucation.com/viewtopic.php?t=12368#p88865
            average_color = (r * 0.3) + (g * 0.59) + (b * 0.11);
          end
          ptx = step_x * x
          pty = step_y * y
          ptz = step_z * average_color
          pts << Geom::Point3d.new( [ptx, pty, ptz] )
        }
      }
      total = pts.size.to_f
      puts "> Processing data took: #{Time.now - start_time}s"
      t = Time.now
      # (!) Bottleneck!
      # Populate the mesh with the point and build an vertex index.
      progress = TT::Progressbar.new( pts, 'Indexing Points' )
      mesh = Geom::PolygonMesh.new( pts.size, pts.size * 2 )
      pi = []
      pts.each_with_index { |pt, i|
        progress.next
        Sketchup.status_text = sprintf("Indexing points: %.1f%%", ( i / total ) * 100.0 )
        pi << mesh.add_point(pt)
      }
      puts "> Indexing points took: #{Time.now - start_time}s"
      t = Time.now
      # Generate the mesh
      progress = TT::Progressbar.new( dib.pixels, 'Generating Mesh' )
      0.upto(dib.height-2) { |y|
        0.upto(dib.width-2) { |x|
          progress.next
          r = y * dib.width # Current row
          Sketchup.status_text = sprintf("Generating mesh: %.1f%%", ( (x+r) / total ) * 100.0 )
          # Pick out the indexes from the patch 2D-matrix we're interested in.
          pos = [ x+r, x+1+r, x+dib.width+1+r, x+dib.width+r ]
          # Get the point indexes and mirror orientation
          indexes = pos.map { |i| pi[i] }
          next unless indexes.length > 2
          mesh.add_polygon([ indexes[0], indexes[1], indexes[2] ])
          mesh.add_polygon([ indexes[0], indexes[2], indexes[3] ])
        }
      }
      puts "> Generating mesh took: #{Time.now - t}s"
      t = Time.now
      Sketchup.status_text = 'Filling group with mesh...'
      # Add the geometry to the model
      group = model.active_entities.add_group
      group.entities.fill_from_mesh( mesh, true, 12 )
      puts "> Filling mesh took: #{Time.now - t}s"
      puts "Total time: #{Time.now - start_time}s"
      group
    end
  
  end # class PlaceMeshTool  
  

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
  
  def self.reload
    load __FILE__
  end
  
end # module TT::Plugins::BitmapToMesh

#-----------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-----------------------------------------------------------------------------