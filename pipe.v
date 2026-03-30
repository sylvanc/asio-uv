use "libuv.so"
{
  uv_pipe_init = "uv_pipe_init"(ffi::ptr, ffi::ptr, i32): i32;
  uv_pipe_open = "uv_pipe_open"(ffi::ptr, i32): i32;
  uv_pipe_bind = "uv_pipe_bind"(ffi::ptr, ffi::ptr): i32;
  uv_pipe_connect = "uv_pipe_connect"(
    uv_req, ffi::ptr, ffi::ptr, ffi::ptr): none;
}

pipe
{
  _state
  {
    _handle: array[u8];
    _r: _stream_reader;
    _w: _stream_writer;
    _on_read: stream_read::cb;
    _on_connect: (_state, i32)->none;
    _connect_cb: ffi::callback[(uv_req, i32)->none];
    _closed: bool;
    _initialized: bool;
    _active: bool;
    _connected: bool;
    _connecting: bool;
    _in_handler: bool;
    _path: string;

    create(): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      let _on_connect = (s: _state, status: i32): none -> {}
      let _connect_cb = ffi::callback (req: uv_req, status: i32): none -> {}

      new
      {
        _handle = handle::pipe,
        _r = _stream_reader,
        _w = _stream_writer,
        _on_read,
        _on_connect,
        _connect_cb,
        _closed = false,
        _initialized = false,
        _active = false,
        _connected = false,
        _connecting = false,
        _in_handler = false,
        _path = ""
      }
    }

    start(self: _state, h: stream_read::cb): none
    {
      if self._closed | (self._active & self._connected)
      {
        return
      }

      self._on_read = h;
      self._activate true;
      self._begin_reads
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

    _fail_read(self: _state): none
    {
      let eof_size: usize = 0;
      self._in_handler = true;
      self._on_read()(self, array[u8]::fill(eof_size), eof_size);
      self._in_handler = false
    }

    _dispatch_read(self: _state, data: array[u8], size: usize): none
    {
      if self._closed | !self._active
      {
        return
      }

      self._in_handler = true;
      self._on_read()(self, data, size);
      self._finish_handler
    }

    _begin_reads(self: _state): none
    {
      if !self._r.start(
        self._handle,
        (data, size) ->
        {
          self._dispatch_read(data, size)
        })
      {
        self._activate false;
        self._fail_read;
        self.close
      }
    }

    _ensure_init(self: _state): bool
    {
      if self._initialized
      {
        return true
      }

      if :::uv_pipe_init(:::uv_default_loop(), self._handle, 0) < 0
      {
        return false
      }

      self._initialized = true;
      true
    }

    open(self: _state, fd: i32): none
    {
      if self._closed
      {
        return
      }

      if !self._ensure_init
      {
        self._fail_read;
        self.close;
        return
      }

      if :::uv_pipe_open(self._handle, fd) < 0
      {
        self._fail_read;
        self.close;
        return
      }

      self._connected = true
    }

    connect(self: _state, path: string, on_connect: (_state, i32)->none): none
    {
      if self._closed
      {
        return
      }

      if !self._ensure_init
      {
        on_connect(self, -1);
        self.close;
        return
      }

      self._path = path.copy;
      self._on_connect = on_connect;
      self._connecting = true;
      self._connect_cb = ffi::callback (req: uv_req, status: i32): none ->
      {
        _req::free(req);
        self._connecting = false;

        if self._closed
        {
          self._activate false;
          return
        }

        self._in_handler = true;
        self._on_connect()(self, status);
        self._finish_handler;

        if self._closed
        {
          self._activate false;
          return
        }

        if status < 0
        {
          self.close;
          return
        }

        self._begin_reads
      }

      self._activate true;

      let req = _req::connect();
      :::uv_pipe_connect(
        req, self._handle, self._path.cstring, self._connect_cb.raw)
    }

    write(self: _state, data: array[u8]): none
    {
      if self._closed | !self._connected
      {
        return
      }

      self._w.write(self._handle, data)
    }

    close(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._closed = true;

      if self._initialized
      {
        self._r.stop(self._handle);
        :::uv_close(self._handle, none)
      }

      if self._active & !self._connecting
      {
        self._activate false
      }
    }

    final(self: _state): none
    {
      if self._closed
      {
        return
      }

      if self._initialized
      {
        self._r.stop(self._handle);
        :::uv_close(self._handle, none)
      }

      if self._active & !self._connecting
      {
        ffi::external.remove;
        ffi::unpin self
      }
    }
  }

  _c: cown[_state];

  create(): pipe
  {
    let _c = cown _state;
    new {_c}
  }

  open(fd: i32): pipe
  {
    let self = pipe;
    self _lock::run p -> p.open fd;
    self
  }

  open(fd: i32, on_read: stream_read::cb): pipe
  {
    let self = pipe;
    self _lock::run p ->
    {
      p.open fd;
      p.start on_read
    }
    self
  }

  connect(
    path: string,
    on_read: stream_read::cb,
    on_connect: (_state, i32)->none): pipe
  {
    let self = pipe;
    self _lock::run p ->
    {
      p._on_read = on_read;
      p.connect path on_connect
    }
    self
  }

  connect(path: string, on_read: stream_read::cb): pipe
  {
    pipe::connect(path, on_read, ((p: _state, status: i32): none -> {}))
  }

  start(self: pipe, h: stream_read::cb): none
  {
    self _lock::run p -> p.start h
  }

  write(self: pipe, data: array[u8]): none
  {
    self _lock::run p -> p.write data
  }

  close(self: pipe): none
  {
    self _lock::run p -> p.close
  }
}
