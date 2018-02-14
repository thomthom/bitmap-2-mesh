module TT::Plugins::BitmapToMesh

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins').add_submenu('Bitmap to Mesh Debug Tools')
    menu.add_item('Profile Heightmap from Selection')  { self.profile_heightmap }

    file_loaded(__FILE__)
  end

  class ImageHelper
    def get_image_definition(image)
      image.model.definitions.each { |definition|
        if definition.image? && definition.instances.include?(image)
          return definition
        end
      }
      nil
    end

    def get_image_material(image)
      definition = get_image_definition(image)
      material_name = "b2m_#{definition.name}"
      model = image.model
      material = model.materials[material_name]
      return material if material
      material = model.materials.add(material_name)
      if image.respond_to?(:image_rep)
        material.texture = image.image_rep
      else
        Bitmap.temp_image_file(image) { |temp_file|
          material.texture = temp_image_file
        }
      end
      material
    end

    def create_material(bitmap)
      material_name = "b2m_image"
      model = Sketchup.active_model
      material = model.materials.add(material_name)
      bitmap.temp_file { |temp_file|
        material.texture = temp_file
      }
      material
    end

    def get_material(image, bitmap)
      # TODO: Clean up this kludgy mess!
      image ? get_image_material(image) : create_material(bitmap)
    end
  end

  def self.profile_heightmap
    Sketchup.require 'SpeedUp'

    model = Sketchup.active_model
    image = model.selection.grep(Sketchup::Image).first

    width = image.width
    height = image.height
    depth = 2.m

    tr = image.transformation
    transformation = Geom::Transformation.axes(image.origin, tr.xaxis, tr.yaxis, tr.zaxis)

    bitmap = Bitmap.from_image(image)
    material = ImageHelper.new.get_material(image, bitmap)
    heightmap = HeightmapMesh.new

    SpeedUp.profile {
      model.start_operation('Mesh From Heightmap', true)
      group = heightmap.generate(model.active_entities, bitmap, width, height, depth, material)
      group.transformation = transformation
      model.commit_operation
    }

  end

end # module
