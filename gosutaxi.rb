#!/usr/bin/env ruby

require 'rubygems'
require 'gosu'
require 'chipmunk'

include Gosu

SCREEN_WIDTH = 640
SCREEN_HEIGHT = 480
TILE_SIZE = 16

SUBSTEPS = 6

def array2poly(array)
  array.map do |vector|
    CP::Vec2.new(vector.first, vector.last)
  end
end

class Numeric 
  def gosu_to_radians
    (self - 90) * Math::PI / 180.0
  end
  
  def radians_to_gosu
    self * 180.0 / Math::PI + 90
  end
  
  def radians_to_vec2
    CP::Vec2.new(Math::cos(self), Math::sin(self))
  end
end


class GameWindow < Window
  attr_reader :space
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
    self.caption = "Gosutaxi"
    @space = CP::Space.new
    @space.damping = 0.95
    @dt = (1.0/60.0)
    @space.gravity = CP::Vec2.new(0, 1)
    @space.iterations = 5
    @map = Map.new(self, "media/level001.txt")
    @space.add_body(@map.static_shapes.first.body)
    @map.static_shapes.each do |shape|
      @space.add_static_shape(shape)
    end
    
    @buttons_pressed = {}
    # TODO: building collision detection [2008-05-02]
    # @space.add_collision_func(:world, :taxi) do |world_shape, taxi_shape|
    #   puts "collision: #{taxi_shape.bb.inspect}"
    #   puts "with: #{world_shape.bb.inspect}"
    # end

    @space.add_collision_func(:world, :taxi_pods) do |world_shape, taxi_shape|
      puts "collision: #{taxi_shape.bb.inspect}"
      puts "with: #{world_shape.bb.inspect}"
    end

    
    # @song = Song.new(self, 'media/darksideofhousemix.mod')
    # @song.play
    @taxi = Taxi.new(self)
  end
  def draw
    @map.draw # @screen_x, @screen_y
    @taxi.draw
  end
  
  def check_buttons
    @buttons_pressed.reject{|k,v| v == false }.keys.each do |key|
      case key
      when Gosu::Button::KbUp
        @taxi.accel_y(-1.0)
      when Gosu::Button::KbLeft
        @taxi.accel_x(-1.0)
      when Gosu::Button::KbRight
        @taxi.accel_x(1.0)
      end      
    end
  end

  def button_down(key)
    close if key == Gosu::Button::KbEscape
    @taxi.toggle_pods if key == Gosu::Button::KbSpace
    @buttons_pressed[key] = true
  end
  def button_up(key)
    @buttons_pressed[key] = false
  end

  def update
    check_buttons
    SUBSTEPS.times do
      @space.step(@dt)
      @taxi.update
    end
  end
  
end

module Tiles
  BottomRight =   0
  TopLeft =       1
  BottomLeft =    2
  TopRight =      3
  Full =          4
  Empty =         5
end

         
class Map
  attr_reader :width, :height, :static_shapes
  
  def initialize(window, filename)
    p filename
    # Load 60x60 tiles, 5px overlap in all four directions.
    @tileset = Image.load_tiles(window, "media/maptiles.png", TILE_SIZE, TILE_SIZE, true)

    lines = File.readlines(filename).map { |line| line }
    @height = lines.size
    @width = lines[0].size
    
    @body = CP::Body.new(Float::MAX, Float::MAX)
    
    @static_shapes = []
    
    @tiles = Array.new(@width) do |x|
      Array.new(@height) do |y| 
        shape_vertices = []      
        tile = case lines[y][x, 1]
        when '#'
          shape_vertices = [CP::Vec2.new(0,0), CP::Vec2.new(0, TILE_SIZE),CP::Vec2.new(TILE_SIZE, TILE_SIZE),CP::Vec2.new(TILE_SIZE, 0)]
          Tiles::Full
        when '1'
          shape_vertices = [CP::Vec2.new(0,0), CP::Vec2.new(0, TILE_SIZE),CP::Vec2.new(TILE_SIZE, 0)]
          Tiles::TopLeft
        when '3'
          shape_vertices = [CP::Vec2.new(0,0), CP::Vec2.new(TILE_SIZE, TILE_SIZE),CP::Vec2.new(TILE_SIZE, 0)]
          Tiles::TopRight
        when '2'
          shape_vertices = [CP::Vec2.new(0,0), CP::Vec2.new(0, TILE_SIZE),CP::Vec2.new(TILE_SIZE, TILE_SIZE)]
          Tiles::BottomLeft
        when '4'
          shape_vertices = [CP::Vec2.new(TILE_SIZE,0), CP::Vec2.new(0, TILE_SIZE),CP::Vec2.new(TILE_SIZE, TILE_SIZE)]
          Tiles::BottomRight
        else
          # shape_vertices = [CP::Vec2.new(-17,-17), CP::Vec2.new(-17, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-17, 16)]
          # Tiles::Full
        end
        if tile
          shape = CP::Shape::Poly.new(@body, shape_vertices, CP::Vec2.new(x * TILE_SIZE, y * TILE_SIZE))
          shape.collision_type = :world
          shape.group = :world
          shape.e = 0
          shape.u = 0
          @static_shapes << shape
        end
        tile
      end
    end
  end
    
  
  def draw # (screen_x, screen_y)

    # Very primitive drawing function:
    # Draws all the tiles, some off-screen, some on-screen.
    @height.times do |y|
      @width.times do |x|
        tile = @tiles[x][y]
        if tile
          # Draw the tile with an offset (tile images have some overlap)
          # Scrolling is implemented here just as in the game objects.
          # @image.draw_rot(@shape.body.p.x, @shape.body.p.y, 1, @sbody.a.radians_to_gosu)
          @tileset[tile].draw(x * TILE_SIZE,  y * TILE_SIZE, 0)
        end
      end
    end
  end
end

class Taxi
  def initialize(window)
    @window = window
    @taxi_tiles = Image.load_tiles(window, 'media/taxi.png', 64, 32, true)
    @x_pos = 100
    @y_pos = 100
    @speed_x = 0
    @speed_y = 0
    @body = CP::Body.new(10.0, Float::MAX)
    vertices_rump = [
      [4,1],
      [4,62],
      [14,63],
      [19,19],
      [16,4],
      [10,0],
      [6,0],
    ]
    vertices_cabin = [
      [20,21],
      [16,51],
      [27,48],
      [31,44],
      [31,30],
      [29,25],
    ]
      
    @shape_rump = CP::Shape::Poly.new(@body, array2poly(vertices_rump), CP::Vec2.new(-16,-32))
    @shape_rump.collision_type = :taxi
    @shape_rump.e = 0    
    @shape_rump.u = 0
    
    @shape_cabin = CP::Shape::Poly.new(@body, array2poly(vertices_cabin), CP::Vec2.new(-16,-32))
    @shape_cabin.collision_type = :taxi
    @shape_cabin.e = 0
    @shape_cabin.u = 0
    
    @shapes_pods = [
      CP::Shape::Segment.new(@body, CP::Vec2.new(5,21), CP::Vec2.new(0,18), 3),
      CP::Shape::Segment.new(@body, CP::Vec2.new(5,43), CP::Vec2.new(0,45), 3),
    ]
    @shapes_pods.each do |shape| 
      shape.e = 0
      shape.u = 0
      @shape_cabin.collision_type = :taxi_pods
    end

    @body.p = CP::Vec2.new(@x_pos,@y_pos)
    @body.a = -Math::PI / 2
    @pods = 0
    window.space.add_shape(@shape_rump)
    window.space.add_shape(@shape_cabin)
    window.space.add_body(@body)  
  end
  
  def update
    #puts @body.v.inspect
    @x_pos += @speed_x
    @y_pos += @speed_y
  end
  
  def draw
    @taxi_tiles[@pods].draw_rot(@body.p.x, @body.p.y, 1, @body.a.radians_to_gosu)
    # @image.draw(@body.p.x,@body.p.y, 2)
  end
  
  def accel_x(acc)
    @body.v += CP::Vec2.new(acc, 0) if @pods == 0
  end
  
  def accel_y(acc)
    @body.v += CP::Vec2.new(0, acc)
  end
  
  # this doesn't really work somehow
  def toggle_pods
    @pods = (@pods + 1) % 2
    if @pods == 1
      @shapes_pods.each do |shape|
        @window.space.add_shape(shape)
      end
    else
      @shapes_pods.each do |shape|
        @window.space.remove_shape(shape)
      end      
    end
  end
  
private
  
end

window = GameWindow.new
window.show
