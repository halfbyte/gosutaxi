#!/usr/bin/env ruby

require 'rubygems'
require 'gosu'
require 'chipmunk'

include Gosu

SCREEN_WIDTH = 640
SCREEN_HEIGHT = 480

class GameWindow < Window
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
    self.caption = "Gosutaxi"
    @space = CP::Space.new
    @space.damping = 0.8
    @space.gravity = CP::Vec2.new(0, 10)
    @map = Map.new(self, "media/level001.txt")
    @map.static_shapes.each do |shape|
      @space.add_static_shape(shape)
    end
    
    
    
    
    # @song = Song.new(self, 'media/darksideofhousemix.mod')
    # @song.play
    @taxi = Taxi.new(self)
  end
  def draw
    @map.draw # @screen_x, @screen_y
    @taxi.draw
  end
  
  def button_down(id)
    case id
    when Gosu::Button::KbEscape
      close
    when Gosu::Button::KbUp
      @taxi.accel_y(-0.5)
    when Gosu::Button::KbDown
      @taxi.accel_y(0.5)
    when Gosu::Button::KbLeft
      @taxi.accel_x(-0.5)
    when Gosu::Button::KbRight
      @taxi.accel_x(0.5)
    end
  end

  def update
    @taxi.update
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
    # Load 60x60 tiles, 5px overlap in all four directions.
    @tileset = Image.load_tiles(window, "media/maptiles.png", 32, 32, true)

    lines = File.readlines(filename).map { |line| line }
    @height = lines.size
    @width = lines[0].size
    
    @body = CP::Body.new(Float::MAX, Float::MAX)
    
    @static_shapes = []
    
    @tiles = Array.new(@width) do |x|
      Array.new(@height) do |y|        
        tile = case lines[y][x, 1]
        when '#'
          shape_vertices = [CP::Vec2.new(-16,-16), CP::Vec2.new(-16, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-16, 16)]
          Tiles::Full
        when '1'
          shape_vertices = [CP::Vec2.new(-16,-16), CP::Vec2.new(-16, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-16, 16)]
          Tiles::TopLeft
        when '3'
          shape_vertices = [CP::Vec2.new(-16,-16), CP::Vec2.new(-16, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-16, 16)]
          Tiles::TopRight
        when '2'
          shape_vertices = [CP::Vec2.new(-16,-16), CP::Vec2.new(-16, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-16, 16)]
          Tiles::BottomLeft
        when '4'
          shape_vertices = [CP::Vec2.new(-16,-16), CP::Vec2.new(-16, 16),CP::Vec2.new(16, 16),CP::Vec2.new(-16, 16)]
          Tiles::BottomRight
        else
          nil
        end
        if tile
          shape = CP::Shape::Poly.new(@body, shape_vertices, CP::Vec2.new(x * 32 - 16, y * 32 - 16))
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
          @tileset[tile].draw(x * 32,  y * 32, 0)
        end
      end
    end
  end
  def static_shapes
    []
  end
end

class Taxi
  def initialize(window)
    @image = Image.new(window, 'media/taxi.png', true)
    @x_pos = 100
    @y_pos = 100
    @speed_x = 0
    @speed_y = 0
    @body = CP::Body.new(10.0, 150.0)
    vertices = [CP::Vec2.new(-32, -16),CP::Vec2.new(-32, 16), CP::Vec2.new(32, 16),CP::Vec2.new(32, -16)]
    @shape = CP::Shape::Poly.new(@body, vertices, CP::Vec2.new(32,16))
  end
  
  def update
    @x_pos += @speed_x
    @y_pos += @speed_y
  end
  
  def draw
    @image.draw(@x_pos,@y_pos, 1)
  end
  
  def accel_x(acc)
    @speed_x += acc
  end
  
  def accel_y(acc)
    @speed_y += acc    
  end
  
end


window = GameWindow.new
window.show
