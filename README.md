# asio-uv

Async I/O for [Verona](https://github.com/sylvanc/verona-bc), powered by [libuv](https://libuv.org).

## Install

Requires libuv (`libuv.so`) installed on your system.

```verona
use asio = "https://github.com/sylvanc/asio-uv" "main"
```

## Quick Start

TCP echo server with a client:

```verona
use asio = "https://github.com/sylvanc/asio-uv" "main"

main(): none
{
  let a = addr 9163;

  tcp_listener(a).start (server, conn) ->
  {
    conn.start (conn, data, size) ->
    {
      if size > 0
      {
        conn.write(data, size);
        conn.shutdown
      }
      else
      {
        conn.close
      }
    }

    server.close
  }

  let client = tcp(a).start (conn, data, size) ->
  {
    if size > 0
    {
      conn.shutdown
    }
    else
    {
      conn.close
    }
  }

  client.write(array[u8]::fill(4, 'h'))
}
```

## API

### Network Addresses

**`addr`** — IPv4/IPv6 socket address.

```verona
addr 8080                        // bind all interfaces, port 8080
addr("127.0.0.1", 8080)         // specific IPv4
addr::ip4("0.0.0.0", 80)        // explicit IPv4
addr::ip6("::", 80)              // explicit IPv6
a.valid                          // true if address is valid
a.port                           // port number
a.ip                             // IP as string
a.family                         // AF_INET=2, AF_INET6=10
```

**`dns`** — DNS resolution.

```verona
(dns "example.com").resolve addrs ->
{
  // addrs: array[addr]
}
```

### TCP

**`tcp`** — TCP client connection.

```verona
let client = tcp(addr 8080).start (conn, data, size) ->
{
  if size > 0
  {
    // data received
    conn.write(data, size)  // echo back
  }
  else
  {
    conn.close              // EOF
  }
}

client.write(array[u8]::fill(4, 'h'))
client.nodelay                   // disable Nagle's algorithm
client.keepalive                 // enable TCP keepalive
client.shutdown                  // graceful shutdown
client.close                     // close connection
```

**`tcp_listener`** — TCP server.

```verona
tcp_listener(addr 8080).start (server, conn) ->
{
  conn.start (conn, data, size) ->
  {
    // handle data / EOF
  }

  server.close                   // stop after first connection
}
```

### UDP

**`udp`** — UDP socket.

```verona
let receiver = udp(addr 9000).start (sock, data, size, sender) ->
{
  if size > 0
  {
    // data received from sender addr
  }

  sock.close
}

udp(addr 0).send(payload, addr 9000)   // send to receiver
```

### Streams

**`stream_read`** — Shape for readable streams (tcp, pipe, tty, file, stdin).

Callback signature: `(stream, data: array[u8], size: usize) -> none`

- `size > 0` — data received
- `size == 0` — EOF or error

**`stream_write`** — Shape for writable streams.

```verona
stream.write data                // write entire array
stream.write(data, size)         // write first `size` bytes
```

### Pipes

**`pipe`** — Named/anonymous pipe.

```verona
pipe.start handler               // start reading
pipe.write data                  // write data
pipe.close                       // close pipe
```

### Terminal

**`tty`** — Terminal I/O.

```verona
tty.start handler                // start reading
tty.on_resize (t, w, h) -> {}   // window resize callback
tty.close
```

**`stdin`** — Standard input (auto-detects tty, pipe, or file).

```verona
let input = stdin;
input.start handler;
input.close
```

### Timers

**`timer`** — One-shot timer.

```verona
timer((t: timer) -> { /* fired */ }) 100   // fire after 100ms
timer.cancel                               // cancel pending timer
```

### Signals

**`signal`** — OS signal handler.

```verona
signal(2, { /* SIGINT */ })       // handle Ctrl+C
signal.close                      // stop handling
signal.unref                      // don't keep event loop alive
```

### Files

**`file`** — File reader (stdin file descriptor).

```verona
file.start handler
file.close
```

## Callback Conventions

All read callbacks follow the same pattern:

- **`size > 0`** — data is available in `data[0..size]`
- **`size == 0`** — EOF or error; close the connection

Methods return `self` for chaining: `tcp(a).start(h).nodelay.keepalive`.

## License

MIT
