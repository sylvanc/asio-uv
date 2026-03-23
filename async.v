use "libuv.so"
{
  uv_async_init = "uv_async_init"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_async_send = "uv_async_send"(ffi::ptr): i32;
  uv_stop = "uv_stop"(ffi::ptr): none;
}

_async
{
  _handle: array[u8];
  _cb: ffi::callback[ffi::ptr->none];

  once create(): _async
  {
    let _handle = array[u8]::fill :::uv_handle_size(1); // UV_ASYNC
    let _cb = ffi::callback (handle: ffi::ptr): none ->
    {
      _semaphore::runtime.post;
      _semaphore::loop.wait;
    }

    :::uv_async_init(:::uv_default_loop(), _handle, _cb.raw);
    new {_handle, _cb}
  }

  once shutdown(): _async
  {
    let _handle = array[u8]::fill :::uv_handle_size(1); // UV_ASYNC
    let _cb = ffi::callback (handle: ffi::ptr): none ->
    {
      _async.close;
      _async::shutdown.close;
      :::uv_stop(:::uv_default_loop())
    }

    :::uv_async_init(:::uv_default_loop(), _handle, _cb.raw);
    new {_handle, _cb}
  }

  send(self: _async): none
  {
    :::uv_async_send(self._handle);
  }

  close(self: _async): none
  {
    :::uv_close(self._handle, none);
  }
}
