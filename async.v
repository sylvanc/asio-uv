_async
{
  use "libuv.so"
  {
    uv_async_init = "uv_async_init"(ffi::ptr, uv_handle, ffi::ptr): i32;
    uv_async_send = "uv_async_send"(uv_handle): i32;
    uv_close = "uv_close"(uv_handle, ffi::ptr): none;
    uv_unref = "uv_unref"(ffi::ptr): none;
    uv_stop = "uv_stop"(uv_handle): none;
  }

  _bootstrap
  {
    use
    {
      malloc = "malloc"(usize): ffi::ptr;
    }

    use "libuv.so"
    {
      uv_default_loop = "uv_default_loop"(): ffi::ptr;
      uv_handle_size = "uv_handle_size"(i32): usize;
      uv_async_init = "uv_async_init"(ffi::ptr, uv_handle, ffi::ptr): i32;
      uv_unref = "uv_unref"(ffi::ptr): none;
    }

    _create(cb: ffi::ptr): uv_handle
    {
      let handle = :::malloc(:::uv_handle_size(1)); // UV_ASYNC
      :::uv_async_init(:::uv_default_loop(), handle, cb);
      handle
    }

    create(cb: ffi::ptr): uv_handle
    {
      let handle = _bootstrap::_create(cb);
      :::uv_unref(handle);
      handle
    }

    create_ref(cb: ffi::ptr): uv_handle
    {
      _bootstrap::_create(cb)
    }
  }

  _handle: uv_handle;
  _cb: ffi::callback[ffi::ptr->none];

  once create(): _async
  {
    let _cb = ffi::callback (handle: ffi::ptr): none ->
    {
      _semaphore::runtime.post;
      _semaphore::loop.wait;
    }

    let _handle = _bootstrap(_cb.raw);
    new {_handle, _cb}
  }

  once shutdown(): _async
  {
    let _cb = ffi::callback (h: ffi::ptr): none ->
    {
      :::uv_close(h, handle::_close_cb.raw);
      _async._close
    }

    let _handle = _bootstrap::create_ref(_cb.raw);
    new {_handle, _cb}
  }

  send(self: _async): _async
  {
    :::uv_async_send(self._handle);
    self
  }

  _close(self: _async): _async
  {
    :::uv_close(self._handle, handle::_close_cb.raw);
    self
  }
}
