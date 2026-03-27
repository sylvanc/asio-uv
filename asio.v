use uv_handle = ffi::ptr;

use "libuv.so"
{
  uv_default_loop = "uv_default_loop"(): ffi::ptr;
  uv_handle_size = "uv_handle_size"(i32): usize;
  uv_close = "uv_close"(uv_handle, ffi::ptr): none;

  init(): ()->none
  {
    signal::sigpipe;

    // Return a fini lambda.
    {
      _async::shutdown.send;
      _loop.join;
    }
  }
}

handle
{
  async(): array[u8]
  {
    handle::_alloc(1) // UV_ASYNC
  }

  pipe(): array[u8]
  {
    handle::_alloc(7) // UV_NAMED_PIPE
  }

  tcp(): array[u8]
  {
    handle::_alloc(12) // UV_TCP
  }

  timer(): array[u8]
  {
    handle::_alloc(13) // UV_TIMER
  }

  tty(): array[u8]
  {
    handle::_alloc(14) // UV_TTY
  }

  udp(): array[u8]
  {
    handle::_alloc(15) // UV_UDP
  }

  signal(): array[u8]
  {
    handle::_alloc(16) // UV_SIGNAL
  }

  _alloc(type: i32): array[u8]
  {
    array[u8]::fill(:::uv_handle_size(type))
  }
}
