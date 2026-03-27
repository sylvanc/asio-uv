use "libuv.so"
{
  uv_pipe_init = "uv_pipe_init"(ffi::ptr, ffi::ptr, i32): i32;
  uv_pipe_open = "uv_pipe_open"(ffi::ptr, i32): i32;
  uv_pipe_bind = "uv_pipe_bind"(ffi::ptr, ffi::ptr): i32;
  uv_pipe_connect = "uv_pipe_connect"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
}