#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
module Image

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
