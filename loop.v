use
{
  platform_thread_size = "platform_thread_size"(): usize;
}

use "libuv.so"
{
  uv_run = "uv_run"(ffi::ptr, i32): i32;
  uv_thread_create = "uv_thread_create"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_thread_join = "uv_thread_join"(ffi::ptr): i32;
  uv_loop_close = "uv_loop_close"(ffi::ptr): i32;
}

_loop
{
  _handle: array[u8];
  _cb: ffi::callback[ffi::ptr->none];

  once create(): _loop
  {
    let _handle = array[u8]::fill(:::platform_thread_size());
    let _cb = ffi::callback (arg: ffi::ptr): none ->
    {
      :::uv_run(:::uv_default_loop(), 0); // UV_RUN_DEFAULT
    }

    :::uv_thread_create(_handle, _cb.raw, none);
    new {_handle, _cb}
  }

  join(self: _loop): none
  {
    :::uv_thread_join(self._handle);
    :::uv_loop_close(:::uv_default_loop());
  }
}
