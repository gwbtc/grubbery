# lick-echo

Demo of grubbery's `/sys/lick` local IPC service. The nexus opens a unix
socket at `<pier>/.urb/dev/grubbery/grubbery/echo` (agent dir + port path
`/grubbery/echo`, no suffix) and echoes every inbound `[mark noun]`
message back to the connected client.

## /sys/lick from a nexus

```hoon
;<  ~  bind:m  (lick-spin:io /my/port)     :: socket: .urb/dev/grubbery/my/port
;<  *  bind:m  (keep:io /in [%& %& /sys/lick/my/port %in] ~)
|-
;<  *  bind:m  (take-news:io /in)          :: wave per inbound message
;<  =seen:nexus  bind:m  (peek:io [%& %& /sys/lick/my/port %in] ~)
::  the in-grub holds [seq=@ud =mark noun=*]; seq bumps per message, so
::  dedup on seq if you might re-peek (see this nexus's loop)
;<  ~  bind:m  (lick-spit:io /my/port %reply 'hi')
```

Connection state (`%connect` / `%disconnect` soaks from the runtime) is
materialized at `/sys/lick/<name>/live` as a loobean; runtime port errors
persist at `/sys/lick/<name>/err`. `lick-shut:io` closes the port and
deletes its tree. Ports respin automatically on agent reload. `/live` is
advisory — a client could send those marks itself; the socket's unix
permissions are the actual security boundary.

## Wire format (verified against vere 4.5)

Each message, both directions: **1 version byte `0x00`, 4-byte
little-endian length, then the jam of `[mark noun]`**. A malformed frame
gets a reply of `[0 [%bail [... %newt-decode]]]` rather than a
disconnect. Note AF_UNIX's ~104-byte path limit — connect via a relative
path or symlink if your pier lives deep.

Tested client:

```python
import socket, struct

class W:  # bitstream writer
    def __init__(self): self.acc = 0; self.len = 0
    def bits(self, val, n):
        self.acc |= (val & ((1 << n) - 1)) << self.len
        self.len += n
    def bytes(self):
        return self.acc.to_bytes((self.len + 7) // 8 or 1, 'little')

def mat(w, a):  # ++mat length-prefixed atom
    if a == 0: return w.bits(1, 1)
    b = a.bit_length(); c = b.bit_length()
    w.bits(1 << c, c + 1)
    w.bits(b & ((1 << (c - 1)) - 1), c - 1)
    w.bits(a, b)

def jam(noun):  # int = atom, 2-tuple = cell
    w = W()
    def go(n):
        if isinstance(n, int): w.bits(0, 1); mat(w, n)
        else: w.bits(1, 2); go(n[0]); go(n[1])
    go(noun)
    return w.bytes()

class R:  # bitstream reader
    def __init__(self, data): self.num = int.from_bytes(data, 'little'); self.pos = 0
    def bit(self):
        b = (self.num >> self.pos) & 1; self.pos += 1; return b
    def bits(self, n):
        v = (self.num >> self.pos) & ((1 << n) - 1); self.pos += n; return v

def rub(r):
    c = 0
    while r.bit() == 0: c += 1
    if c == 0: return 0
    b = r.bits(c - 1) | (1 << (c - 1))
    return r.bits(b)

def cue(data):
    r = R(data); memo = {}
    def go():
        at = r.pos
        if r.bit() == 0: n = rub(r)
        elif r.bit() == 0: n = (go(), go())
        else: return memo[rub(r)]
        memo[at] = n
        return n
    return go()

def cord(s): return int.from_bytes(s.encode(), 'little')
def uncord(a): return a.to_bytes((a.bit_length() + 7) // 8, 'little').decode()

def send(sock, mark, noun):
    body = jam((cord(mark), noun))
    sock.sendall(b'\x00' + struct.pack('<I', len(body)) + body)

def recv(sock):
    hdr = b''
    while len(hdr) < 5:
        c = sock.recv(5 - len(hdr))
        if not c: raise EOFError
        hdr += c
    assert hdr[0] == 0
    n = struct.unpack('<I', hdr[1:5])[0]
    body = b''
    while len(body) < n:
        c = sock.recv(n - len(body))
        if not c: raise EOFError
        body += c
    return cue(body)

s = socket.socket(socket.AF_UNIX)
s.connect('.urb/dev/grubbery/grubbery/echo')  # relative to the pier
send(s, 'noun', cord('round trip!'))
mark, payload = recv(s)
print(f'[%{uncord(mark)} {uncord(payload)!r}]')  # [%noun 'round trip!']
```
