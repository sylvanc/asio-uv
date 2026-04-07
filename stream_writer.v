use "libuv.so"
{
  uv_write = "uv_write"(uv_req, uv_handle, uv_buf, i32, ffi::ptr): i32;
}

_stream_writer
{
  use write_cb = ffi::callback[(uv_req, i32)->none];

  cb: write_cb;

  create(): _stream_writer
  {
    let cb = write_cb (req: uv_req, status: i32): none ->
    {
      let buf = :::uv_req_get_data(req);
      let data = _uv_buf_type.load[array[u8]](buf, 0);
      ffi::unpin data;
      _uv_buf_type.free buf;
      _req::free req;
    }

    new {cb}
  }

  write(
    self: _stream_writer, handle: uv_handle, data: array[u8], size: usize): none
  {
    let sz = size min data.size;
    ffi::pin data;
    let buf = _uv_buf_type.alloc;
    _uv_buf_type.store[array[u8]](buf, 0, data);
    _uv_buf_type.store[usize](buf, 1, sz);

    let req = _req::write;
    :::uv_req_set_data(req, buf);
    let status = :::uv_write(req, handle, buf, 1, self.cb.raw);

    if status < 0
    {
      ffi::unpin data;
      _uv_buf_type.free buf;
      _req::free req
    }
  }
}
