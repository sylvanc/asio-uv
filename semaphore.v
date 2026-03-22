use "libuv.so"
{
  uv_sem_init = "uv_sem_init"(ffi::ptr, u32): i32;
  uv_sem_post = "uv_sem_post"(ffi::ptr): none;
  uv_sem_wait = "uv_sem_wait"(ffi::ptr): none;
  uv_sem_destroy = "uv_sem_destroy"(ffi::ptr): none;
}

_semaphore
{
  _handle: array[u8];

  once loop(): _semaphore
  {
    _semaphore 0
  }

  once runtime(): _semaphore
  {
    _semaphore 0
  }

  create(count: u32): _semaphore
  {
    let _handle = array[u8]::fill(32); // sizeof(uv_sem_t)
    :::uv_sem_init(_handle, count);
    new {_handle}
  }

  post(self: _semaphore): none
  {
    :::uv_sem_post self._handle
  }

  wait(self: _semaphore): none
  {
    :::uv_sem_wait self._handle
  }

  final(self: _semaphore): none
  {
    :::uv_sem_destroy self._handle
  }
}
