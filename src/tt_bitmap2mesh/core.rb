#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/helpers/image'
require 'tt_bitmap2mesh/image/image_rep'
require 'tt_bitmap2mesh/debug'
require 'tt_bitmap2mesh/bitmap'
require 'tt_bitmap2mesh/place_mesh_tool'


module TT::Plugins::BitmapToMesh

  # Sketchup.write_default("tt_bitmap2mesh", "DebugMode", true)
  if Sketchup.read_default(PLUGIN_ID, "DebugMode", false)
    require 'tt_bitmap2mesh/debug_tools'
  end


  unless file_loaded?(__FILE__)
    menu = UI.menu('Draw')
    menu.add_item('Mesh From Heightmap')  { self.bitmap_to_mesh_tool }

    UI.add_context_menu_handler { |context_menu|
      selection = Sketchup.active_model.selection
      if selection.length == 1 && selection[0].is_a?(Sketchup::Image)
        image = selection[0]
        context_menu.add_item('Mesh From Heightmap') { self.heightmap_to_mesh(image) }
        context_menu.add_item('Mesh From Bitmap')    { self.image_to_mesh(image, use_builder: false) }
        context_menu.add_item('Mesh From Bitmap (Builder)')    { self.image_to_mesh(image) }
      end
    }
    file_loaded(__FILE__)
  end


  def self.bitmap_to_mesh_tool
    if defined?(Sketchup::ImageRep)
      filetypes = %w[bmp jpg jpeg png psd tif tga]
      filter = filetypes.map { |filetype| "*.#{filetype}" }.join(';')
      filter = "Image Files|#{filter}||"
      filename = UI.openpanel('Select image file', nil, filter)
    else
      filename = UI.openpanel('Select BMP File', nil, '*.bmp')
    end
    return if filename.nil?
    bitmap = Bitmap.new(filename)
    tool = PlaceMeshTool.new(bitmap)
    Sketchup.active_model.tools.push_tool(tool)
    tool
  rescue ImageRep::InvalidFileError
    UI.messagebox('Unable to load image. Unrecognized format.')
  rescue Exception => error
    ERROR_REPORTER.handle(error)
  end


  def self.heightmap_to_mesh(image)
    bitmap = Bitmap.from_image(image)
    tool = PlaceMeshTool.new(bitmap, image)
    Sketchup.active_model.tools.push_tool(tool)
    tool
  rescue Exception => error
    ERROR_REPORTER.handle(error)
  end


  # @param [Sketchup::Image] image
  # @param [Boolean] use_builder
  def self.image_to_mesh(image, use_builder: true)
    t = Time.now
    bitmap = Bitmap.from_image(image)
    puts "> Bitmap from image took: #{Time.now - t}s)"
    model = Sketchup.active_model
    t = Time.now
    model.start_operation('Mesh From Bitmap', true)
    group = model.active_entities.add_group
    group.description = 'Mesh from Bitmap'
    group.transform!(Image.transformation(image))
    entities = group.entities
    if entities.respond_to?(:build) && use_builder
      entities.build do |builder|
        build_faces(bitmap, builder)
      end
    else
      build_faces(bitmap, entities)
    end
    model.commit_operation
    puts "> Image to mesh took: #{Time.now - t}s (Builder: #{use_builder})"
  rescue Exception => error
    ERROR_REPORTER.handle(error)
  end

  # @param [Bitmap] bitmap
  # @param [Sketchup::Entities, Sketchup::EntitiesBuilder] builder
  def self.build_faces(bitmap, builder)
    bitmap.height.times { |y|
      bitmap.width.times { |x|
        index = (bitmap.width * y) + x
        color = bitmap.data[index]
        points = [
          [x,     y,     0],
          [x + 1, y,     0],
          [x + 1, y + 1, 0],
          [x,     y + 1, 0]
        ]
        face = builder.add_face(points)
        # Ensure face's front side is oriented upwards. SketchUp will try to
        # force it to point downwards - preparing it to be push-pulled.
        face.reverse! unless face.normal.samedirection?(Z_AXIS)
        face.material = color
      }
    }
  end


end # module
