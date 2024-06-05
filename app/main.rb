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

def generate_ff(begin_as = false)
  state = begin_as
  ->(toggle) { state ^= (toggle ? true : false) }
end

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

  $slowmo_ff = generate_ff

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
      x: 150,
      y: 360,
      w: 60,
      h: 540,
      path: :pixel,
      **spd
    },
    {
      x: 500,
      y: 360,
      w: 200,
      h: 100,
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
  player.x += player.vx
  player.y += player.vy

  py = player.y
  px = player.x
  ph = player.h
  pw = player.w

  anchor_x = player.anchor_x
  player_left = px - anchor_x * pw
  player_right = px + (1 - anchor_x) * pw

  anchor_y = player.anchor_y
  player_bot = py - anchor_y * ph
  player_top = py - (1 - anchor_y) * ph

  player.y += (vy = player.vy) / 2
  player.x += (vx = player.vx) / 2
  player.h += vy.abs
  player.w += vx.abs

  walls = $geometry.find_all_intersect_rect(player, $level_geometry)
  player.y = py
  player.x = px
  player.h = ph
  player.w = pw

  # return if walls.empty?

  # :nodoc:
  dx = dy = Float::INFINITY

  sty = {}
  stx = {}

  wally = walls.min_by { |w|
    sy = py <=> w.y
    dyc = ((sty[w] = w.y + (((w.h * (1 - w.anchor_y)) + (ph * anchor_y)) * sy)) - py).abs
    dy = dy < dyc ? dy : dyc
    dyc
  }

  wallx = walls.min_by { |w|
    sx = px <=> w.x
    dxc = ((stx[w] = w.x + (((w.w * (1 - w.anchor_x)) + (pw * anchor_x)) * sx)) - px).abs
    dx = dx < dxc ? dx : dxc
    dxc
  }

  unless walls.empty?

    if wallx == wally
      if (dx + vx) < (dy + vy)
        player.x = stx[wallx]
        player.vx = 0
      else
        player.y = sty[wallx]
        player.vy = 0
      end
    else
      player.x = stx[wallx]
      player.y = sty[wally]
      player.vx = 0
      player.vy = 0
    end
  end

  ap_grav(player)
  ap_fric(player, $has_accelerated ? 0.1 : 0.2)
end

def input
  keyboard = $inputs.keyboard
  keys_held = keyboard.key_held
  keys_down = keyboard.key_down

  player = $player
  pda = $player_default_accel

  if keys_held.left
    player.vx -= pda
    $has_accelerated = true
  end
  if keys_held.right
    player.vx += pda
    $has_accelerated = true
  end
  if keys_down.up
    grappleable_wall = $level_geometry.filter { player_can_wall_grapple?(_1) }.min_by { (_1.x - player.x).abs }
    if grappleable_wall
      player.vy = $player_default_jump
      player.vx = (grappleable_wall.x <=> player.x) * -10
    else
      player.vy = Math.log(player.vy < 0 ? $player_default_jump / 2 : player.vy + $player_default_jump, 1.2)
    end
  end

  if keys_down.q
    $player.y = 410 + 24 # + 24
    $player.x = 400 - 15
  end

  player.vy -= pda * 2 if keys_held.down

  $init_done = false if keys_down.r
  return unless $slowmo_ff[keys_down.forward_slash]

  $gtk.slowmo!(5)
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

  $render_queue.concat([{
                         x: player.x,
                         y: player.y,
                         x2: $level_geometry[-1].x,
                         y2: $level_geometry[-1].y,
                         r: 255,
                         primitive_marker: :line
                       }, {
                         x: player.x + player.vx,
                         y: player.y + player.vy,
                         x2: $level_geometry[-1].x,
                         y2: $level_geometry[-1].y,
                         b: 255,
                         primitive_marker: :line
                       }])

  # $render_queue << {**$geometry.rect_props($player), r: 255, primitive_marker: :border}
end

# tick
def tick(args)
  $init_done ||= init

  outputs = args.outputs

  input

  handle_player

  fill_renderq

  outputs.primitives.concat($render_queue)
  $render_queue.clear
  $has_accelerated = false
  outputs.background_color = $bg_color
end
