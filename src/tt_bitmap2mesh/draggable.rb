#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/text'


module TT::Plugins::BitmapToMesh
  module Draggable

    def initialize(*args)
      super
      @events = {}
    end

    # Properties

    def reset
      @drag = false
      @mouse_down_position = nil
    end

    def drag?
      @drag
    end

    # Events

    def on_drag(&block)
      @events[:drag] = block
    end

    def on_drag_complete(&block)
      @events[:drag_complete] = block
    end

    # Tool Listener

    def onLButtonDown(flags, x, y, view)
      if mouse_over?(x, y, view)
        @mouse_down_position = Geom::Point3d.new(x, y, 0)
        true
      else
        false
      end
    end

    def onLButtonUp(flags, x, y, view)
      capture = !@mouse_down_position.nil?
      if @mouse_down_position
        mouse_position = Geom::Point3d.new(x, y, 0)
        direction = @mouse_down_position.vector_to(mouse_position)
        @events[:drag_complete].call(direction) if @events[:drag_complete]
      end
      @mouse_down_position = nil
      @drag = false
      capture
    end

    def onMouseMove(flags, x, y, view)
      if @mouse_down_position
        mouse_position = Geom::Point3d.new(x, y, 0)
        direction = @mouse_down_position.vector_to(mouse_position)
        @drag = mouse_position != @mouse_down_position
        @events[:drag].call(direction) if @events[:drag]
        true
      else
        @drag = false
        false
      end
      # mouse_over?(x, y, view)
    end

    private

    def mouse_over?(x, y, view)
      raise NotImplementedError
    end

  end # class
end # module
