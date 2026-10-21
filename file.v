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

    create(_fd: i32): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      new {_fd, _on_read, _cb = ffi::callback[(uv_req)->none]()}
    }

    start(self: _state, h: stream_read::cb): _state
    {
      if self._fd == -1
      {
        return self
      }

      self._on_read = h;
      ffi::pin self;
      ffi::external.add;

      self._cb = ffi::callback (req: uv_req): none ->
      {
        let buf = :::uv_req_get_data(req);
        let data = _uv_buf_type.load[array[u8]](buf, 0);
        ffi::unpin data;

        let nread = :::uv_fs_get_result(req);
        :::uv_fs_req_cleanup(req);
        _uv_buf_type.free buf;
        _req::free req;

        if self._fd == -1
        {
          return
        }

        if nread > 0
        {
          self._on_read()(self, data, nread.usize);
          self._read
        }
        else
        {
          self._on_read()(self, data, 0);
          self.close
        }
      }

      self._read
    }

    close(self: _state): _state
    {
      if self._fd == -1
      {
        return self
      }

      let req = _req::fs;
      :::uv_fs_close(:::uv_default_loop(), req, self._fd, none);
      :::uv_fs_req_cleanup(req);
      _req::free req

      self._fd = -1;
      ffi::external.remove;
      ffi::unpin self;
      self
    }

    _read(self: _state): _state
    {
      if self._fd == -1
      {
        return self
      }

      let data = array[u8]::fill 4096;
      ffi::pin data;

      let buf = _uv_buf_type.alloc();
      _uv_buf_type.store[array[u8]](buf, 0, data);
      _uv_buf_type.store[usize](buf, 1, data.size);

      let req = _req::fs();
      :::uv_req_set_data(req, buf);

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
        ffi::unpin data;
        :::uv_fs_req_cleanup(req);
        _uv_buf_type.free buf;
        _req::free req;
        self._on_read()(self, data, 0);
        self.close
      }

      self
    }

    final(self: _state): none
    {
      if self._fd == -1
      {
        return
      }

      // This will only occur if `start` is never called.
      let req = _req::fs;
      :::uv_fs_close(:::uv_default_loop(), req, self._fd, none);
      :::uv_fs_req_cleanup(req);
      _req::free req
    }
  }

  _c: cown[_state];

  _stdin(): file
  {
    let _c = cown _state 0;
    mem::freeze new {_c}
  }

  start(self: file, h: stream_read::cb): file
  {
    self._c _lock::run f -> f.start h;
    self
  }

  close(self: file): file
  {
    self._c _lock::run f -> f.close;
    self
  }
}
