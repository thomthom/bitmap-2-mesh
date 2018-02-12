#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/dib_render'


module TT::Plugins::BitmapToMesh
  class PlaceMeshTool

    S_START = 0
    S_RECT  = 1
    S_BOX   = 2

    def initialize(dib, image = nil)
      @dib = dib
      @ratio = dib.width.to_f / dib.height.to_f

      @dib_render = DIBRender.new(@dib)

      @ip_start = Sketchup::InputPoint.new
      @ip_rect  = Sketchup::InputPoint.new
      @ip_mouse = Sketchup::InputPoint.new

      @image = image
    end

    def enableVCB?
      true
    end

    def activate
      reset
      update_dib_render_transformation
    end

    def reset
      @ip_start.clear
      @ip_rect.clear
      @ip_mouse.clear

      @ph = nil

      @state = S_START

      if @image
        @ip_start = Sketchup::InputPoint.new(@image.origin)
        pt = @image.origin.offset(@image.normal.axes.x, @image.width)
        pt.offset!(@image.normal.axes.y, @image.height)
        @ip_rect = Sketchup::InputPoint.new(pt)
        @state = S_BOX
      end

      update_ui
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
        pts = get_box
        Sketchup.vcb_value = pts[0].distance(pts[1])
      when S_BOX
        Sketchup.status_text = 'Pick depth.'
        Sketchup.vcb_label = 'Depth:'
        pts = get_box
        Sketchup.vcb_value = pts[0].distance(pts[4])
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
      when S_RECT
        pts = get_box
        vx = pts[0].vector_to(pts[1])
        if vx.valid?
          pt = @ip_start.position.offset(vx, length)
          @ip_rect = Sketchup::InputPoint.new(pt)
          @state = S_BOX
        end
      when S_BOX
        pts = get_box
        normal = pts[0].vector_to(pts[4])
        unless normal.valid?
          vx = pts[0].vector_to(pts[1])
          vy = pts[0].vector_to(pts[3])
          normal = vx * vy
        end
        pt = @ip_start.position.offset(normal, length)
        @ip_mouse = Sketchup::InputPoint.new(pt)
        generate_mesh
      end
      update_ui
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      @ip_mouse.pick(view, x, y)
      view.tooltip = @ip_mouse.tooltip
      update_dib_render_transformation
      #@ph = view.pick_helper(x, y)
      #@ph.do_pick(x, y)
      view.invalidate
      update_ui
    end

    def onLButtonUp(flags, x, y, view)
      case @state
      when S_START
        #ph = view.pick_helper(x, y)
        #ph.do_pick(x, y)
        #bp = ph.best_picked
        #if bp.is_a?(Sketchup::Image)
        #  @image = bp
        #  reset
        #else
          @ip_start.copy!(@ip_mouse)
          @state = S_RECT
          update_dib_render_transformation
        #end
      when S_RECT
        @ip_rect.copy!(@ip_mouse)
        @state = S_BOX
        update_dib_render_transformation
      when S_BOX
        generate_mesh
      end
      view.invalidate
      update_ui
    end

    def update_dib_render_transformation
      box = get_box
      if @state == S_RECT || @state == S_BOX
        x_axis = box[0].vector_to(box[1])
        y_axis = box[0].vector_to(box[3])
        if x_axis.valid? && y_axis.valid?
          # TODO: Cache transformation.
          box_size = [x_axis.length, y_axis.length].max
          scale = box_size.to_f / 64.0
          if @state == S_BOX
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
          @dib_render.transformation = tr_origin * tr_scale
        end
      end
    end

    def draw(view)
      @ip_mouse.draw(view) if @ip_mouse.valid?

      box = get_box

      if @state == S_RECT || @state == S_BOX
        xaxis = box[0].vector_to(box[1])
        yaxis = box[0].vector_to(box[3])
        if xaxis.valid? && yaxis.valid?
          @dib_render.draw(view)
        end
      end

      view.line_width = 2
      view.line_stipple = ''
      view.drawing_color = [255,0,0]

      # box = get_box

      #if @state == S_START
      #  bp = @ph.best_picked
      #  if bp.is_a?(Sketchup::Image)
      #    axes = bp.normal.axes
      #    rect = []
      #    rect << bp.origin
      #    rect << rect.last.offset(axes.x, bp.width)
      #    rect << rect.last.offset(axes.y, bp.height)
      #    rect << rect.first.offset(axes.y, bp.height)
      #    view.draw(GL_LINE_LOOP, rect)
      #  end
      #end

      if @state == S_RECT || @state == S_BOX
        view.draw(GL_LINE_LOOP, box[0..3])
      end

      if @state == S_BOX
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
      bb = Geom::BoundingBox.new
      pts = get_box
      pts.each { |pt|
        bb.add(pt)
      }
      # bb.add(@dib_render.bounds)
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
        pt2 = ip2.position.project_to_line([pt1, vx])
        width = pt1.distance(pt2)
        height = width / @ratio
        pt3 = pt2.offset(vy, height)
        pt4 = pt1.offset(vy, height)

        rect_lower = [pt1, pt2, pt3, pt4]
        pts.concat(rect_lower)
      end

      if @state == S_BOX
        # HACK(thomthom): Clean this up. Get pick_rway from mouse event.
        view = Sketchup.active_model.active_view
        pick_ray = [view.camera.eye, @ip_mouse.position]
        image_ray = [@image.origin, @image.normal]
        pt5, pt_pick = Geom.closest_points(image_ray, pick_ray)

        # mp = @ip_mouse.position
        # pt5 = mp.project_to_line([pt1, vz])
        depth = pt1.vector_to(pt5)
        pt6 = pt2.offset(depth)
        pt7 = pt3.offset(depth)
        pt8 = pt4.offset(depth)

        rect_upper = [pt5, pt6, pt7, pt8]
        pts.concat(rect_upper)
      end
      pts
    end

    def generate_mesh
      box = get_box
      xaxis = box[0].vector_to(box[1])
      yaxis = box[0].vector_to(box[3])
      zaxis = box[0].vector_to(box[4])
      width  = xaxis.length
      height = yaxis.length
      depth  = zaxis.length
      origin = box[0]
      model = Sketchup.active_model
      model.start_operation('Mesh From Heightmap', true)
      t = Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
      g = bitmap_to_mesh(@dib, width, height, depth)
      g.transformation = t
      model.commit_operation
      model.tools.pop_tool
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
      progress = TT::Progressbar.new(dib.pixels, 'Reading Image')
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
          pts << Geom::Point3d.new([ptx, pty, ptz])
        }
      }
      total = pts.size.to_f
      puts "> Processing data took: #{Time.now - start_time}s"
      t = Time.now
      # (!) Bottleneck!
      # Populate the mesh with the point and build an vertex index.
      progress = TT::Progressbar.new(pts, 'Indexing Points')
      mesh = Geom::PolygonMesh.new(pts.size, pts.size * 2)
      pi = []
      pts.each_with_index { |pt, i|
        progress.next
        Sketchup.status_text = sprintf("Indexing points: %.1f%%", (i / total) * 100.0)
        pi << mesh.add_point(pt)
      }
      puts "> Indexing points took: #{Time.now - start_time}s"
      t = Time.now
      # Generate the mesh
      progress = TT::Progressbar.new(dib.pixels, 'Generating Mesh')
      0.upto(dib.height-2) { |y|
        0.upto(dib.width-2) { |x|
          progress.next
          r = y * dib.width # Current row
          Sketchup.status_text = sprintf("Generating mesh: %.1f%%", ((x+r) / total) * 100.0)
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
      group.entities.fill_from_mesh(mesh, true, 12)
      puts "> Filling mesh took: #{Time.now - t}s"
      puts "Total time: #{Time.now - start_time}s"
      group
    end

  end # class PlaceMeshTool
end # module
