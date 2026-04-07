use uv_req = ffi::ptr;
use uv_buf = ffi::ptr;
use _uv_buf_type = ffi::struct[(array[u8], usize)];

use "libuv.so"
{
  uv_req_size = "uv_req_size"(i32): usize;
  uv_req_get_data = "uv_req_get_data"(uv_req): uv_buf;
  uv_req_set_data = "uv_req_set_data"(uv_req, uv_buf): none;
}

shape stream_read
{
  use cb = (stream_read, array[u8], usize)->none;

  start(self: self, h: cb): self;
  close(self: self): self;
}

shape stream_write
{
  write(self: self, data: array[u8]): self;
  write(self: self, data: array[u8], size: usize): self;
}

_req
{
  req(): uv_req
  {
    :::malloc(:::uv_req_size(1)) // UV_REQ
  }

  connect(): uv_req
  {
    :::malloc(:::uv_req_size(2)) // UV_CONNECT
  }

  write(): uv_req
  {
    :::malloc(:::uv_req_size(3)) // UV_WRITE
  }

  shutdown(): uv_req
  {
    :::malloc(:::uv_req_size(4)) // UV_SHUTDOWN
  }

  udp_send(): uv_req
  {
    :::malloc(:::uv_req_size(5)) // UV_UDP_SEND
  }

  fs(): uv_req
  {
    :::malloc(:::uv_req_size(6)) // UV_FS
  }

  getaddrinfo(): uv_req
  {
    :::malloc(:::uv_req_size(8)) // UV_GETADDRINFO
  }

  getnameinfo(): uv_req
  {
    :::malloc(:::uv_req_size(9)) // UV_GETNAMEINFO
  }

  free(req: uv_req): none
  {
    :::free(req)
  }
}
