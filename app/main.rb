$init_done = false
$bg_color = { r: 25, g: 25, b: 25 }
$render_queue = []
$player = nil
$level_geometry = nil
$sane_positioning_data = { anchor_x: 0.5, anchor_y: 0.5 }
$player_default_accel = 1
$default_gravity_coef = 2
$player_default_jump = 15 * $default_gravity_coef**0.5

if $gtk.production?
  def p!(...)
  end
else
  def p!(...)
    p(...)
  end
end

def init
  p!("init ran")

  spd = $sane_positioning_data

  $player = {
    x: 100,
    y: 100,
    w: 32,
    h: 48,
    path: :pixel,
    vx: 0,
    vy: 0,
    ax: 0,
    ay: 0,
    **spd
  }

  $level_geometry = [
    {
      x: 640,
      y: 30,
      w: 1240,
      h: 20,
      path: :pixel,
      **spd
    }
  ]

  true
end

def ap_grav(obj)
  obj.vy -= 1
end

def ap_vel(obj)
  obj.x += obj.vx
  obj.y += obj.vy
end

def ap_fric(obj, fric = 0.05)
  rv = 1 - fric
  obj.vx *= rv
  # obj.vy *= rv
end

def collision_vert?(o1, o2)
  lw1 = (w1 = o1.w) * o1.anchor_x
  rw1 = w1 - lw1
  lw2 = (w2 = o2.w) * o2.anchor_x
  rw2 = w2 - lw2
  x1 = o1.x
  x2 = o2.x
  (x1 - lw1 < x2 + rw2) && (x1 + rw1 > x2 - lw2)
end

def collision_horiz?(o1, o2)
end

def handle_player
  player = $player
  ap_grav(player)
  ap_vel(player)
  ap_fric(player, 0.1)

  opy = player.y
  oph = player.h

  player.y += (vy = player.vy) / 2
  player.h += vy.abs

  $render_queue << { **player, g: 0, b: 0 }
  
  wall = $geometry.find_intersect_rect($player, $level_geometry)
  player.y = opy
  player.h = oph
  if wall
    if collision_vert?(player, wall) # i hate you rubocop <3
      sy = player.y <=> wall.y
      player.y = wall.y + (((wall.h * (1 - wall.anchor_y)) + (player.h * player.anchor_y)) * sy)
      player.vy = 0
    end

    if collision_horiz?(player, wall)
      puts "rubocop1"
      puts "rubocop2"
    end
  end

  1
end

def input
  keyboard = $inputs.keyboard
  keys_held = keyboard.key_held
  keys_down = keyboard.key_down

  player = $player
  pda = $player_default_accel

  player.vx -= pda if keys_held.left
  player.vx += pda if keys_held.right
  player.vy += $player_default_jump if keys_down.up
  player.vy -= pda * 2 if keys_held.down
end

def fill_renderq
  $render_queue << $player
  $render_queue.concat($level_geometry)
end

# tick
def tick(args)
  $init_done ||= init

  outputs = args.outputs

  input

  handle_player

  fill_renderq

  outputs.primitives.concat($render_queue)
  $render_queue = []
  outputs.background_color = $bg_color
end
