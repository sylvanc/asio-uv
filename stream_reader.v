use "libuv.so"
{
  uv_read_start = "uv_read_start"(uv_handle, ffi::ptr, ffi::ptr): i32;
  uv_read_stop = "uv_read_stop"(uv_handle): i32;
}

_stream_reader
{
  use alloc_cb = ffi::callback[(uv_handle, i32, uv_buf)->none];
  use read_cb = ffi::callback[(uv_handle, isize, uv_buf)->none];

  acb: alloc_cb;
  rcb: read_cb;
  _active: bool;

  create(): _stream_reader
  {
    let acb = alloc_cb
      (handle: uv_handle, suggested_size: i32, buf: uv_buf): none ->
    {
      // Every alloc_cb call has a read_cb call, but not vice versa.
      let data = array[u8]::fill(suggested_size.usize);
      ffi::pin(data);
      _uv_buf_type.store[array[u8]](buf, 0, data);
      _uv_buf_type.store[usize](buf, 1, suggested_size.usize);
    }

    let rcb = read_cb (handle: uv_handle, nread: isize, buf: uv_buf): none -> {}
    new {acb, rcb, _active = false}
  }

  start(
    self: _stream_reader,
    handle: uv_handle,
    on_read: (array[u8], usize)->none): bool
  {
    self.stop handle;

    self.rcb = read_cb (handle: uv_handle, nread: isize, buf: uv_buf): none ->
    {
      // It's possible to get a read_cb for a null buffer.
      let size = _uv_buf_type.load[usize](buf, 1);

      if size == 0
      {
        on_read(array::fill 0, 0);
        return
      }

      let data = _uv_buf_type.load[array[u8]](buf, 0);
      ffi::unpin(data);

      if nread > 0
      {
        on_read(data, nread.usize)
      }
      else if nread < 0
      {
        // Don't surface anything for EAGAIN/EWOULDBLOCK.
        // All other errors and EOF are treated as EOF.
        on_read(data, 0)
      }
    }

    if :::uv_read_start(handle, self.acb.raw, self.rcb.raw) < 0
    {
      return false
    }

    self._active = true;
    true
  }

  stop(self: _stream_reader, handle: uv_handle): none
  {
    if self._active
    {
      :::uv_read_stop(handle);
      self._active = false
    }
  }
}
