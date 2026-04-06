use uv_handle = ffi::ptr;

use
{
  malloc = "malloc"(usize): ffi::ptr;
  free = "free"(ffi::ptr): none;
}

use "libuv.so"
{
  uv_default_loop = "uv_default_loop"(): ffi::ptr;
  uv_handle_size = "uv_handle_size"(i32): usize;
  uv_close = "uv_close"(uv_handle, ffi::ptr): none;

  init(): ()->none
  {
    // Block SIGPIPE without keeping the watcher loop-ref'ed.
    signal(13, {}).unref; // SIGPIPE

    // Return a fini lambda.
    {
      :::uv_tty_reset_mode();
      _async::shutdown.send;
      _loop.join;
    }
  }
}

handle
{
  create(): uv_handle
  {
    ffi::ptr
  }

  async(): uv_handle
  {
    handle::_alloc(1) // UV_ASYNC
  }

  pipe(): uv_handle
  {
    handle::_alloc(7) // UV_NAMED_PIPE
  }

  tcp(): uv_handle
  {
    handle::_alloc(12) // UV_TCP
  }

  timer(): uv_handle
  {
    handle::_alloc(13) // UV_TIMER
  }

  tty(): uv_handle
  {
    handle::_alloc(14) // UV_TTY
  }

  udp(): uv_handle
  {
    handle::_alloc(15) // UV_UDP
  }

  signal(): uv_handle
  {
    handle::_alloc(16) // UV_SIGNAL
  }

  open(self: uv_handle): bool
  {
    self != ffi::ptr
  }

  close(self: uv_handle): uv_handle
  {
    if handle::open self
    {
      _lock::run
      {
        :::uv_close(self, handle::_close_cb.raw)
      }
    }

    ffi::ptr
  }

  once _close_cb(): ffi::callback[ffi::ptr->none]
  {
    ffi::callback (h: ffi::ptr): none ->
    {
      :::free(h)
    }
  }

  _alloc(type: i32): uv_handle
  {
    :::malloc(:::uv_handle_size(type))
  }
}
