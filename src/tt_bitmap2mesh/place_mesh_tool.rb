#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/bitmap'
require 'tt_bitmap2mesh/bitmap_render'


module TT::Plugins::BitmapToMesh
  class PlaceMeshTool

    module State
      PICK_ORIGIN = 0
      PICK_IMAGE_SIZE = 1
      PICK_HEIGHT = 2
    end

    def initialize(bitmap, image = nil)
      @bitmap = bitmap
      @ratio = bitmap.width.to_f / bitmap.height.to_f # TODO: Make property of Bitmap.

      # Renders low-res preview of the heightmap.
      @bitmap_render = BitmapRender.new(@bitmap)

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
        point = @image.origin.offset(@image.normal.axes.x, @image.width)
        point.offset!(@image.normal.axes.y, @image.height)
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
        points = get_bounding_points
        Sketchup.vcb_value = points[0].distance(points[1])
      when State::PICK_HEIGHT
        Sketchup.status_text = 'Pick depth.'
        Sketchup.vcb_label = 'Depth:'
        points = get_bounding_points
        Sketchup.vcb_value = points[0].distance(points[4])
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
        points = get_bounding_points
        x_axis = points[0].vector_to(points[1])
        if x_axis.valid?
          point = @ip_start.position.offset(x_axis, length)
          @ip_rect = Sketchup::InputPoint.new(point)
          @state = State::PICK_HEIGHT
        end
      when State::PICK_HEIGHT
        points = get_bounding_points
        z_axis = points[0].vector_to(points[4])
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
      @ip_mouse.pick(view, x, y)
      view.tooltip = @ip_mouse.tooltip
      update_dib_render_transformation
      view.invalidate
      update_ui
    end

    def onLButtonUp(flags, x, y, view)
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
      view.invalidate
      update_ui
    end

    def update_dib_render_transformation
      box = get_bounding_points
      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        x_axis = box[0].vector_to(box[1])
        y_axis = box[0].vector_to(box[3])
        if x_axis.valid? && y_axis.valid?
          # TODO: Cache transformation.
          box_size = [x_axis.length, y_axis.length].max
          scale = box_size.to_f / 64.0
          if @state == State::PICK_HEIGHT
            z_axis = box[0].vector_to(box[4])
            scale_z = z_axis.length
            # Check direction:
            dot = (x_axis * y_axis) % z_axis
            scale_z = -scale_z if dot < 0.0
          else
            scale_z = 0
          end
          tr_scale = Geom::Transformation.scaling(scale, scale, scale_z)
          tr_origin = Geom::Transformation.new(box[0], x_axis, y_axis)
          @bitmap_render.transformation = tr_origin * tr_scale
        end
      end
    end

    def draw(view)
      @ip_mouse.draw(view) if @ip_mouse.valid?

      box = get_bounding_points

      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        xaxis = box[0].vector_to(box[1])
        yaxis = box[0].vector_to(box[3])
        if xaxis.valid? && yaxis.valid?
          @bitmap_render.draw(view)
        end
      end

      view.line_width = 2
      view.line_stipple = ''
      view.drawing_color = [255,0,0]

      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        view.draw(GL_LINE_LOOP, box[0..3])
      end

      if @state == State::PICK_HEIGHT
        view.draw(GL_LINE_LOOP, box[4..7])

        connectors = [
          box[0], box[4],
          box[1], box[5],
          box[2], box[6],
          box[3], box[7]
        ]
        view.draw(GL_LINES, connectors)
      end
    end

    def getExtents
      bounds = Geom::BoundingBox.new
      get_bounding_points.each { |point| bounds.add(point) }
      bounds
    end

    # TODO: Return a Bounds class that include methods for the computations
    # done with these points. This would be a class that is different from
    # Geom::BoundingBox because it should represent the orientation in model
    # space.
    def get_bounding_points
      points = []
      if @state == State::PICK_IMAGE_SIZE || @state == State::PICK_HEIGHT
        if @image
          x_axis = @image.normal.axes.x
          y_axis = @image.normal.axes.y
          z_axis = @image.normal.axes.z
          plane = [@image.origin, z_axis]
        else
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
        height = width / @ratio
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
        image_ray = [pt1, Z_AXIS]
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
      points
    end

    def generate_mesh
      box = get_bounding_points
      x_axis = box[0].vector_to(box[1])
      y_axis = box[0].vector_to(box[3])
      z_axis = box[0].vector_to(box[4])
      width  = x_axis.length
      height = y_axis.length
      depth  = z_axis.length
      origin = box[0]
      model = Sketchup.active_model
      model.start_operation('Mesh From Heightmap', true)
      tr = Geom::Transformation.new(x_axis, y_axis, z_axis, origin)
      group = bitmap_to_mesh(@bitmap, width, height, depth)
      group.transformation = tr
      model.commit_operation
      # Once the mesh is generated the tool is popped from the stack and
      # returned to the previous tool.
      model.tools.pop_tool
    end

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

    def bitmap_to_mesh(bitmap, width, height, depth)
      model = Sketchup.active_model

      step_x = width  / bitmap.width
      step_y = height / bitmap.height
      step_z = depth  / 255

      puts "Bitmap To Mesh: (#{bitmap.provider})"
      puts "> Pixels: #{bitmap.width * bitmap.height} (#{bitmap.width}x#{bitmap.height})"
      puts "> Triangles: #{bitmap.width * bitmap.height * 2}"
      start_time = Time.now

      # Read colour values and generate 3D points.
      # TODO: Reuse logic in BitmapRender. It dupliates the greyscale logic.
      #       Additionally the down-sampling logic can be used, but need UI
      #       allow the user to control max-sample size.
      points = []
      w = bitmap.width
      h = bitmap.height
      u_step = 1.0 / bitmap.width.to_f
      v_step = 1.0 / bitmap.height.to_f
      # progress = TT::Progressbar.new(bitmap.pixels, 'Reading Image')
      bitmap.height.times { |y|
        bitmap.width.times { |x|
          # progress.next
          index = (bitmap.width * y) + x
          color = bitmap.data[index]
          # Generate a Point3d from pixel colour.
          point_x = step_x * x
          point_y = step_y * y
          point_z = step_z * color.luminance
          points << Geom::Point3d.new(point_x, point_y, point_z)
        }
      }
      total = points.size.to_f
      puts "> Processing data took: #{Time.now - start_time}s"

      t = Time.now
      # (!) Bottleneck!
      # Populate the mesh with the point and build an vertex index.
      # progress = TT::Progressbar.new(points, 'Indexing Points')
      mesh = Geom::PolygonMesh.new(points.size, points.size * 2)
      mesh_indicies = []
      points.each_with_index { |point, i|
        # progress.next
        # Sketchup.status_text = sprintf("Indexing points: %.1f%%", (i / total) * 100.0)
        mesh_indicies << mesh.add_point(point)

        y = i / h
        x = i - (h * y)
        u = x * u_step
        v = y * v_step
        mesh.set_uv(i + 1, [u, v, 0], true)
      }
      puts "> Indexing points took: #{Time.now - start_time}s"

      # Compute UV mapping:
      #   t = Time.now
      #   w = bitmap.width
      #   h = bitmap.height
      #   u_step = 1.0 / bitmap.width.to_f
      #   v_step = 1.0 / bitmap.height.to_f
      #   # progress = TT::Progressbar.new(points, 'Adding UV mapping')
      #   points.each_with_index { |pt, i|
      #     # progress.next
      #     # Sketchup.status_text = sprintf("UV Mapping: %.1f%%", (i / total) * 100.0)
      #     y = i / h
      #     x = i - (h * y)
      #     u = x * u_step
      #     v = y * v_step
      #     uv = Geom::Point3d.new(u, v, 0)
      #     mesh.set_uv(i + 1, uv, true)
      #   }
      #   puts "> UV mapping took: #{Time.now - t}s"
      # end

      t = Time.now
      # Generate the mesh
      # progress = TT::Progressbar.new(bitmap.pixels, 'Generating Mesh')
      0.upto(bitmap.height-2) { |y|
        0.upto(bitmap.width-2) { |x|
          # progress.next
          r = y * bitmap.width # Current row
          # Sketchup.status_text = sprintf("Generating mesh: %.1f%%", ((x+r) / total) * 100.0)
          # Pick out the indicies from the patch 2D-matrix we're interested in.
          point_indicies = [ x+r, x+1+r, x+bitmap.width+1+r, x+bitmap.width+r ]
          # Get the point indicies and mirror orientation
          indicies = point_indicies.map { |i| mesh_indicies[i] }
          next unless indicies.length > 2
          mesh.add_polygon(indicies[0], indicies[1], indicies[2])
          mesh.add_polygon(indicies[0], indicies[2], indicies[3])
        }
      }
      puts "> Generating mesh took: #{Time.now - t}s"

      t = Time.now
      Sketchup.status_text = 'Filling group with mesh...'
      # Add the geometry to the model
      group = model.active_entities.add_group
      flags = 4 | 8 # AUTO_SOFTEN | SMOOTH_SOFT_EDGES
      if mesh.respond_to?(:set_uv)
        # material = image ? Image.clone_material(image) : Bitmap.create_material(model)
        material = get_material(@image, @bitmap)
        group.entities.fill_from_mesh(mesh, true, flags, material)
      else
        group.entities.fill_from_mesh(mesh, true, flags)
      end
      puts "> Filling mesh took: #{Time.now - t}s"
      puts "Total time: #{Time.now - start_time}s"
      group
    end

  end # class PlaceMeshTool
end # module
