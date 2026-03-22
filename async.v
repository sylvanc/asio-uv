use "libuv.so"
{
  uv_async_init = "uv_async_init"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_async_send = "uv_async_send"(ffi::ptr): i32;
}

_async
{
  _handle: array[u8];
  _cb: ffi::callback;

  once create(): _async
  {
    let _handle = array[u8]::fill(:::uv_handle_size 1); // UV_ASYNC
    let _cb = ffi::callback (handle: array[u8]): none ->
    {
      _semaphore::runtime.post;
      _semaphore::loop.wait;
    }

    :::uv_async_init(:::uv_default_loop, _handle, _cb);
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

  final(self: _async): none
  {
    self._cb.free;
  }
}
