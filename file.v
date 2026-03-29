use "libuv.so"
{
  uv_fs_read = "uv_fs_read"(
    ffi::ptr, uv_req, i32, uv_buf, u32, i64, ffi::ptr): i32;
  uv_fs_close = "uv_fs_close"(ffi::ptr, uv_req, i32, ffi::ptr): i32;
  uv_fs_get_result = "uv_fs_get_result"(uv_req): isize;
  uv_fs_req_cleanup = "uv_fs_req_cleanup"(uv_req): none;
}

file
{
  _state
  {
    _fd: i32;
    _on_read: stream_read::cb;
    _cb: ffi::callback[(uv_req)->none];
    _closed: bool;
    _active: bool;
    _pending: bool;
    _in_handler: bool;

    create(_fd: i32): _state
    {
      let _cb = ffi::callback (req: uv_req): none -> {}
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}

      new
      {
        _fd,
        _on_read,
        _cb,
        _closed = false,
        _active = false,
        _pending = false,
        _in_handler = false
      }
    }

    start(self: _state, h: stream_read::cb): none
    {
      if self._closed | self._active
      {
        return
      }

      self._on_read = h;
      self._cb = ffi::callback (req: uv_req): none ->
      {
        let buf = :::uv_req_get_data(req);
        let data = _uv_buf_type.load[array[u8]](buf, 0);
        ffi::unpin(data);
        let nread = :::uv_fs_get_result(req);
        :::uv_fs_req_cleanup(req);
        _uv_buf_type.free(buf);
        _req::free(req);
        self._pending = false;

        if self._closed
        {
          self._activate false;
          return
        }

        self._in_handler = true;

        if nread > 0
        {
          self._on_read()(self, data, nread.usize)
        }
        else
        {
          self._on_read()(self, data, 0)
        }

        self._finish_handler;

        if self._closed
        {
          self._activate false;
          return
        }

        if nread > 0
        {
          self._read
        }
        else
        {
          self.close
        }
      }

      self._activate true;
      self._read
    }

    close(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._closed = true;

      if self._active & !self._pending
      {
        self._activate false
      }

      let req = _req::fs();
      :::uv_fs_close(:::uv_default_loop(), req, self._fd, none);
      :::uv_fs_req_cleanup(req);
      _req::free(req)
    }

    _activate(self: _state, active: bool): none
    {
      if self._active == active
      {
        return
      }

      self._active = active;

      if !self._in_handler
      {
        if active
        {
          ffi::pin self;
          ffi::external.add
        }
        else
        {
          ffi::external.remove;
          ffi::unpin self
        }
      }
    }

    _finish_handler(self: _state): none
    {
      self._in_handler = false;

      if !self._active
      {
        ffi::external.remove;
        ffi::unpin self
      }
    }

    _read(self: _state): none
    {
      if self._closed
      {
        return
      }

      let data = array[u8]::fill(4096);
      ffi::pin(data);
      let buf = _uv_buf_type.alloc();
      _uv_buf_type.store[array[u8]](buf, 0, data);
      _uv_buf_type.store[usize](buf, 1, data.size);

      let req = _req::fs();
      :::uv_req_set_data(req, buf);
      self._pending = true;

      let status =
        :::uv_fs_read(
          :::uv_default_loop(),
          req,
          self._fd,
          buf,
          1,
          -1,
          self._cb.raw);

      if status < 0
      {
        self._pending = false;
        ffi::unpin(data);
        :::uv_fs_req_cleanup(req);
        _uv_buf_type.free(buf);
        _req::free(req);
        self._in_handler = true;
        self._on_read()(self, data, 0);
        self._finish_handler;

        if !self._closed
        {
          self.close
        }
      }
    }

    final(self: _state): none
    {
      if self._closed
      {
        return
      }

      if self._active & !self._pending
      {
        ffi::external.remove;
        ffi::unpin self
      }

      let req = _req::fs();
      :::uv_fs_close(:::uv_default_loop(), req, 0, none);
      :::uv_fs_req_cleanup(req);
      _req::free(req)
    }
  }

  _c: cown[_state];

  stdin(): file
  {
    let _c = cown _state 0;
    new {_c}
  }

  start(self: file, h: stream_read::cb): none
  {
    self _lock::run f -> f.start h
  }

  close(self: file): none
  {
    self _lock::run f -> f.close
  }
}
