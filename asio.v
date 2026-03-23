use "libuv.so"
{
  uv_default_loop = "uv_default_loop"(): ffi::ptr;
  uv_handle_size = "uv_handle_size"(i32): usize;
  uv_close = "uv_close"(ffi::ptr, ffi::ptr): none;

  init(): ()->none
  {
    // Return a fini lambda.
    {
      _async::shutdown.send;
      _loop.join;
    }
  }
}
