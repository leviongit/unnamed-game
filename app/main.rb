$init_done = false
$bg_color = { r: 25, g: 25, b: 25 }
$render_queue = []
$player = nil
$level_geometry = nil
$sane_positioning_data = { anchor_x: 0.5, anchor_y: 0.5 }
$player_default_accel = 1
$default_gravity_coef = 2
$player_default_jump = 15 * $default_gravity_coef**0.5

$gtk.disable_framerate_warning!

module GTK
  module Notify
    def tick_notification(...)
    end
  end
end

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
    r: 0,
    g: 128,
    b: 255,
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
    },
    {
      x: 1250,
      y: 360,
      w: 20,
      h: 680,
      path: :pixel,
      **spd
    },
    {
      x: 30,
      y: 360,
      w: 20,
      h: 680,
      path: :pixel,
      **spd
    },
    {
      x: 640,
      y: 690,
      w: 1240,
      h: 20,
      path: :pixel,
      **spd
    },
    {
      x: 120,
      y: 360,
      w: 20,
      h: 540,
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

def ap_fric(obj, fric = 0.2)
  rv = 1 - fric
  obj.vx *= rv
  # obj.vy *= rv
end

def collision_vert?(o1, o2, _tol = 1)
  lw1 = (w1 = o1.w) * o1.anchor_x
  rw1 = w1 - lw1
  lw2 = (w2 = o2.w) * o2.anchor_x
  rw2 = w2 - lw2
  x1 = o1.x
  x2 = o2.x
  l1 = x1 - lw1
  r1 = x1 + rw1
  l2 = x2 - lw2
  r2 = x2 + rw2
  (l1 < r2) && (r1 > l2)
  # ((l1 - r2).abs < tol) || ((r1 - l2).abs < tol)
end

def player_can_wall_grapple?(onto)
  player = $player
  opw = player.w
  oph = player.h

  vx = player.vx.abs
  vx = vx < 1 ? 1 : vx
  
  player.w += vx
  player.h -= 10

  v = $geometry.intersect_rect?(player, onto, -1)
  player.w = opw
  player.h = oph

  v
end

def collision_horiz?(o1, o2, _tol = 1)
  bh1 = (h1 = o1.h) * o1.anchor_y
  th1 = h1 - bh1
  bh2 = (h2 = o2.h) * o2.anchor_y
  th2 = h2 - bh2
  y1 = o1.y
  y2 = o2.y
  b1 = y1 - bh1
  t1 = y1 + th1
  b2 = y2 - bh2
  t2 = y2 + th2
  (b1 < t2) && (t1 > b2)
  # ((b1 - t2).abs < tol) || ((t1 - b2).abs < tol)
end

def handle_player
  player = $player

  ap_grav(player)
  ap_vel(player)
  ap_fric(player, 0.1)

  opy = player.y
  opx = player.x
  oph = player.h
  opw = player.w

  player.y += (vy = player.vy) / 2
  player.x += (vx = player.vx) / 2
  player.h += vy.abs
  player.w += vx.abs

  walls = $geometry.find_all_intersect_rect(player, $level_geometry)
  player.y = opy
  player.x = opx
  player.h = oph
  player.w = opw
  return unless walls.length > 0

  dx = dy = Float::INFINITY
  

  sty = {}
  stx = {}

  wally = walls.min_by { |w|
    sy = opy <=> w.y
    dyc = ((sty[w] = w.y + (((w.h * (1 - w.anchor_y)) + (player.h * player.anchor_y)) * sy)) - opy).abs
    dy = dy < dyc ? dy : dyc
    dyc
  }

  wallx = walls.min_by { |w|
    sx = opx <=> w.x
    dxc = ((stx[w] = w.x + (((w.w * (1 - w.anchor_x)) + (player.w * player.anchor_x)) * sx)) - opx).abs
    dx = dx < dxc ? dx : dxc
    dxc
  }

  if wallx != wally
    player.x = stx[wallx]
    player.y = sty[wally]
    player.vx = 0
    player.vy = 0
  elsif dx < dy
    player.x = stx[wallx]
    player.vx = 0
  else
    player.y = sty[wallx]
    player.vy = 0
  end
end

def input
  keyboard = $inputs.keyboard
  keys_held = keyboard.key_held
  keys_down = keyboard.key_down

  player = $player
  pda = $player_default_accel

  player.vx -= pda if keys_held.left
  player.vx += pda if keys_held.right
  if keys_down.up
    grappleable_wall = $level_geometry.filter { player_can_wall_grapple?(_1) }.min_by { (_1.x - player.x).abs }
    if grappleable_wall
      player.vy = $player_default_jump
      player.vx = (grappleable_wall.x <=> player.x) * -10
    else
      player.vy = Math.log((player.vy < 0) ? $player_default_jump / 2 : player.vy + $player_default_jump, 1.2)
    end
  end
  player.vy -= pda * 2 if keys_held.down
  

  $init_done = false if keys_down.r
  return unless keys_held.forward_slash

  $gtk.slowmo!(12)
end

def fill_renderq
  player = $player
  playertrails = 5.map { |i|
    playertrail = { **player, g: 64, b: 128, r: 0, a: 255 / (i + 1) }
    playertrail.y -= i * player.vy / 2
    playertrail.x -= i * player.vx / 2
    playertrail
  }

  
  
  $render_queue.concat(playertrails)
  $render_queue << player
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
