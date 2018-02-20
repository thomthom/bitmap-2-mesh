#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/helpers/image'
require 'tt_bitmap2mesh/bitmap'
require 'tt_bitmap2mesh/bitmap_render'
require 'tt_bitmap2mesh/bounding_box'
require 'tt_bitmap2mesh/heightmap'
require 'tt_bitmap2mesh/leader'


module TT::Plugins::BitmapToMesh
  class PlaceMeshTool

    module State
      PICK_ORIGIN = 0
      PICK_IMAGE_SIZE = 1
      PICK_HEIGHT = 2
    end

    def initialize(bitmap, image = nil)
      @bitmap = bitmap
      @sample_size = [@bitmap.width, @bitmap.height].max

      # Renders low-res preview of the heightmap.
      @bitmap_render = BitmapRender.new(@bitmap)

      # Leader to read out the size of the heightmap
      num_triangles = (@bitmap.width - 1) * (@bitmap.height - 1) * 2
      @leaders = {
        origin: Leader.new("#{num_triangles} triangles"),
        x_axis: Leader.new("#{@bitmap.width}px (100%)"),
        y_axis: Leader.new("#{@bitmap.height}px (100%)"),
      }
      @leaders.each { |id, leader|
        leader.on_drag { |vector2d| on_scale_bitmap(vector2d) }
        leader.on_drag_complete { |vector2d|
          on_scale_bitmap(vector2d)
          @sample_size =  @sample_size_mouse
          @sample_size_mouse = nil
        }
      }

      # The Sketchup::Image entity to generate the mesh from.
      @image = image

      @ip_start = Sketchup::InputPoint.new
      @ip_rect  = Sketchup::InputPoint.new
      @ip_mouse = Sketchup::InputPoint.new

      # Keeps track of the tool's state.
      @state = nil
    end

    def enableVCB?
      true
    end

    def activate
      reset
    end

    def reset
      @ip_start.clear
      @ip_rect.clear
      @ip_mouse.clear

      @state = State::PICK_ORIGIN

      # If an image is already provided then extract position and other state
      # data from that.
      if @image
        @ip_start = Sketchup::InputPoint.new(@image.origin)
        tr = Image.transformation(@image)
        point = tr.origin.offset(tr.xaxis, @image.width)
        point.offset!(tr.yaxis, @image.height)
        @ip_rect = Sketchup::InputPoint.new(point)
        @state = State::PICK_HEIGHT
      end

      update_dib_render_transformation
      update_ui
    end

    def update_ui
      case @state
      when State::PICK_ORIGIN
        Sketchup.status_text = 'Pick origin. Picking a point on a face will orient the mesh to the face.'
        Sketchup.vcb_label = ''
        Sketchup.vcb_value = ''
      when State::PICK_IMAGE_SIZE
        Sketchup.status_text = 'Pick width.'
        Sketchup.vcb_label = 'Width:'
        Sketchup.vcb_value = get_bounding_box.width
      when State::PICK_HEIGHT
        Sketchup.status_text = 'Pick depth.'
        Sketchup.vcb_label = 'Depth:'
        Sketchup.vcb_value = get_bounding_box.depth
      end
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
    end

    def onCancel(reason, view)
      reset
      view.invalidate
    end

    def onUserText(text, view)
      length = text.to_l
      return if length == 0
      case @state
      when State::PICK_IMAGE_SIZE
        x_axis = get_bounding_box.x_axis
        if x_axis.valid?
          point = @ip_start.position.offset(x_axis, length)
          @ip_rect = Sketchup::InputPoint.new(point)
          @state = State::PICK_HEIGHT
        end
      when State::PICK_HEIGHT
        z_axis = get_bounding_box.z_axis
        unless z_axis.valid?
          x_axis = points[0].vector_to(points[1])
          y_axis = points[0].vector_to(points[3])
          z_axis = x_axis * y_axis
        end
        point = @ip_start.position.offset(z_axis, length)
        @ip_mouse = Sketchup::InputPoint.new(point)
        generate_mesh
      end
    ensure
      update_ui
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      return if @leaders.any? { |_, leader| leader.onMouseMove(flags, x, y, view) }
      @ip_mouse.pick(view, x, y)
      view.tooltip = @ip_mouse.tooltip
      update_dib_render_transformation
    ensure
      view.invalidate
      update_ui
    end

    def onLButtonDown(flags, x, y, view)
      @leaders.any? { |_, leader| leader.onLButtonDown(flags, x, y, view) }
    end

    def onLButtonUp(flags, x, y, view)
      return if @leaders.any? { |_, leader| leader.onLButtonUp(flags, x, y, view) }
      case @state
      when State::PICK_ORIGIN
        @ip_start.copy!(@ip_mouse)
        @state = State::PICK_IMAGE_SIZE
        update_dib_render_transformation
      when State::PICK_IMAGE_SIZE
        @ip_rect.copy!(@ip_mouse)
        @state = State::PICK_HEIGHT
        update_dib_render_transformation
      when State::PICK_HEIGHT
        generate_mesh
      end
    ensure
      view.invalidate
      update_ui
    end

    def onSetCursor
      @leaders.any? { |_, leader| leader.onSetCursor }
    end

    # TODO: Rename this method to something more appropriate.
    def update_dib_render_transformation
      box = get_bounding_box
      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        x_axis = box.x_axis
        y_axis = box.y_axis
        if x_axis.valid? && y_axis.valid?
          # TODO: Cache transformation.
          box_size = [x_axis.length, y_axis.length].max
          scale = box_size.to_f / @bitmap_render.max_size
          if @state == State::PICK_HEIGHT
            z_axis = box.z_axis
            scale_z = z_axis.length
            # Check direction:
            dot = (x_axis * y_axis) % z_axis
            scale_z = -scale_z if dot < 0.0
          else
            scale_z = 0
          end
          tr_scale = Geom::Transformation.scaling(scale, scale, scale_z)
          tr_origin = Geom::Transformation.new(box.origin, x_axis, y_axis)
          @bitmap_render.transformation = tr_origin * tr_scale
          # Update leader positions.
          @leaders[:origin].position = box.origin
          @leaders[:x_axis].position = box.origin.offset(x_axis, x_axis.length / 2.0)
          @leaders[:y_axis].position = box.origin.offset(y_axis, y_axis.length / 2.0)
        end
      end
    end

    def draw(view)
      @ip_mouse.draw(view) if @ip_mouse.valid?

      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        box = get_bounding_box

        # Bitmap Preview
        @bitmap_render.draw(view) if box.have_area?

        # Boundingbox
        view.line_width = 2
        view.line_stipple = ''
        view.drawing_color = [255, 0, 0]
        box.draw(view)

        # Leaders
        @leaders.each { |_, leader| leader.draw(view) }
      end
    end

    def getExtents
      bounds = Geom::BoundingBox.new
      get_bounding_box.points.each { |point| bounds.add(point) }
      bounds
    end

    private

    def get_bounding_box
      points = []
      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        if @image
          tr = Image.transformation(@image)
          x_axis = tr.xaxis
          y_axis = tr.yaxis
          z_axis = tr.zaxis
          plane = [@image.origin, z_axis]
        else
          # TODO: Review this. Doesn't look like it will infere the face
          #       orientation correctly. And it should probably only allow
          #       rectangular faces.
          face = @ip_start.face
          x_axis = (face) ? face.normal.axes.x : X_AXIS
          y_axis = (face) ? face.normal.axes.y : Y_AXIS
          z_axis = (face) ? face.normal.axes.z : Z_AXIS
          plane = (face) ? face.plane : [ORIGIN, Z_AXIS]
        end

        # Picked origin location.
        pt1 = @ip_start.position
        # Project second input point to the X axis of the image.
        ip2 = (@state == State::PICK_IMAGE_SIZE) ? @ip_mouse : @ip_rect
        pt2 = ip2.position.project_to_line([pt1, x_axis])
        # This defines the width of the boundingbox from where we can also
        # infere the height.
        width = pt1.distance(pt2)
        height = width / @bitmap.ratio
        # Now we have all the info needed to compute the remaining points of
        # the lower rectangle.
        pt3 = pt2.offset(y_axis, height)
        pt4 = pt1.offset(y_axis, height)

        lower_rectangle = [pt1, pt2, pt3, pt4]
        points.concat(lower_rectangle)
      end

      if @state == State::PICK_HEIGHT
        # HACK(thomthom): Clean this up. Get pick_ray from mouse event.
        view = Sketchup.active_model.active_view
        pick_ray = [view.camera.eye, @ip_mouse.position]
        # Create a line in the direction of the image's normal. We'll use the
        # image's origin as an arbitrary reference point. (Could easily have
        # been something like the centre.)
        image_ray = [pt1, z_axis]
        # From that we find the closest point to the image which will define the
        # height of the height mesh.
        pt5, pt_pick = Geom.closest_points(image_ray, pick_ray)
        depth = pt1.vector_to(pt5)
        pt6 = pt2.offset(depth)
        pt7 = pt3.offset(depth)
        pt8 = pt4.offset(depth)

        upper_rectangle = [pt5, pt6, pt7, pt8]
        points.concat(upper_rectangle)
      end
      BoundingBox.new(points)
    end

    def generate_mesh
      box = get_bounding_box
      x_axis = box.x_axis
      y_axis = box.y_axis
      z_axis = box.z_axis

      # Compute the X and Y scale based on the bitmap's width and height minus
      # one because; a 100x100 pixel image produce 99x99 faces.
      x_scale = x_axis.length / (@bitmap.width - 1)
      y_scale = y_axis.length / (@bitmap.height - 1)
      height  = z_axis.length
      tr_scaling = Geom::Transformation.scaling(ORIGIN, x_scale, y_scale, 1)
      tr_axes = Geom::Transformation.axes(box.origin, x_axis, y_axis, z_axis)
      transformation = tr_axes * tr_scaling

      model = Sketchup.active_model
      model.start_operation('Mesh From Heightmap', true)
      heightmap = HeightmapMesh.new
      material = get_or_create_material(model, @image, @bitmap)
      group = heightmap.generate(model.active_entities, @bitmap, height,
                                 material, transformation)
      model.commit_operation
      # Once the mesh is generated the tool is popped from the stack and
      # returned to the previous tool.
      model.tools.pop_tool
    end

    def get_or_create_material(model, image, bitmap)
      return nil unless Geom::PolygonMesh.instance_methods.include?(:set_uv)
      material = image ? Image.clone_material(image) : bitmap.create_material(model)
    end

    def on_scale_bitmap(vector)
      # Convert the mouse movement vector to an offset value:
      y = -vector.y
      # size_offset = (y * 0.25).to_i
      size_offset = y.to_i
      max_size = @sample_size + size_offset
      # p [vector, y, size_offset]

      # Work out the new bitmap size:
      bitmap_max = [@bitmap.width, @bitmap.height].max
      @sample_size_mouse = clamp(2, max_size, bitmap_max)
      @bitmap_render.max_size = clamp(2, max_size, [bitmap_max, 64].min)

      # Refresh the leader information:
      sample_size = @sample_size_mouse || @sample_size
      scale = sample_size.to_f / bitmap_max.to_f
      w = (@bitmap.width * scale).to_i
      h = (@bitmap.height * scale).to_i
      num_triangles = (w - 1) * (h - 1) * 2
      percent = (scale * 100).to_i
      @leaders[:origin].text = "#{num_triangles} triangles"
      @leaders[:x_axis].text = "#{w}px (#{percent}%)"
      @leaders[:y_axis].text = "#{h}px (#{percent}%)"

      update_dib_render_transformation
      Sketchup.active_model.active_view.invalidate
    end

    def clamp(min, val, max)
      [min, val, max].sort[1]
    end

  end # class PlaceMeshTool
end # module
