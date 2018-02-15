#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/bitmap'


module TT::Plugins::BitmapToMesh
module Image

  def self.clone_material(image)
    definition = self.definition(image)
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

  def self.definition(image)
    image.model.definitions.find { |definition|
      definition.image? && definition.instances.include?(image)
    }
  end

  def self.transformation(image)
    if image.respond_to?(:transformation)
      return image.transformation
    end
    # (!) Doesn't handle flipped images correctly.
    origin = image.origin
    axes = image.normal.axes
    x_scale = image.width / image.pixelwidth
    y_scale = image.height / image.pixelheight
    tr_scaling = Geom::Transformation.scaling(ORIGIN, x_scale, y_scale, 1)
    tr_rotation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, image.zrotation)
    tr_axes = Geom::Transformation.axes(origin, axes.x, axes.y, axes.z)
    tr = tr_axes * tr_rotation * tr_scaling
    tr
  end

end # module
end # module
