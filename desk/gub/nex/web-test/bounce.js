var canvas = document.getElementById('canvas');
var ctx = canvas.getContext('2d');
var W, H;

function resize() {
  W = canvas.width = window.innerWidth;
  H = canvas.height = window.innerHeight;
}
resize();
window.addEventListener('resize', resize);

var balls = [];
var gravity = 0.4;
var damping = 0.8;
var colors = ['#FF6B6B','#4ECDC4','#45B7D1','#96CEB4','#FFEAA7','#DDA0DD','#98D8C8','#F7DC6F'];

function spawn(x, y) {
  balls.push({
    x: x,
    y: y,
    vx: (Math.random() - 0.5) * 12,
    vy: (Math.random() - 0.5) * 8,
    r: 12 + Math.random() * 24,
    color: colors[Math.floor(Math.random() * colors.length)],
    trail: []
  });
}

// start with a few
for (var i = 0; i < 5; i++) {
  spawn(W * Math.random(), H * 0.3 * Math.random());
}

canvas.addEventListener('click', function(e) {
  for (var i = 0; i < 3; i++) spawn(e.clientX, e.clientY);
});

function frame() {
  ctx.fillStyle = 'rgba(18, 18, 24, 0.15)';
  ctx.fillRect(0, 0, W, H);

  for (var i = 0; i < balls.length; i++) {
    var b = balls[i];
    b.trail.push({x: b.x, y: b.y});
    if (b.trail.length > 8) b.trail.shift();

    b.vy += gravity;
    b.x += b.vx;
    b.y += b.vy;

    if (b.x - b.r < 0)     { b.x = b.r;     b.vx = Math.abs(b.vx) * damping; }
    if (b.x + b.r > W)     { b.x = W - b.r;  b.vx = -Math.abs(b.vx) * damping; }
    if (b.y + b.r > H)     { b.y = H - b.r;  b.vy = -Math.abs(b.vy) * damping; }
    if (b.y - b.r < 0)     { b.y = b.r;      b.vy = Math.abs(b.vy) * damping; }

    // trail
    for (var j = 0; j < b.trail.length; j++) {
      var t = b.trail[j];
      var a = (j + 1) / b.trail.length * 0.3;
      ctx.beginPath();
      ctx.arc(t.x, t.y, b.r * (j / b.trail.length) * 0.6, 0, Math.PI * 2);
      ctx.fillStyle = b.color.replace(')', ',' + a + ')').replace('rgb', 'rgba').replace('##', '#');
      ctx.globalAlpha = a;
      ctx.fill();
    }

    // ball
    ctx.globalAlpha = 1;
    ctx.beginPath();
    ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
    ctx.fillStyle = b.color;
    ctx.fill();

    // highlight
    ctx.beginPath();
    ctx.arc(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.3, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.3)';
    ctx.fill();
  }

  var stats = document.getElementById('stats');
  if (stats) stats.textContent = balls.length + ' balls';

  requestAnimationFrame(frame);
}

frame();
