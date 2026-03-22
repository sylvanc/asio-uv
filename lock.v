_lock
{
  _batching: bool;

  once create(): cown[_lock]
  {
    cown(new { _batching = false })
  }

  run[A, B](some: A, handler: B->none): none
  {
    when (_lock, some._c) (l, c) ->
    {
      (*l).acquire;
      handler(*c)
    }
  }

  acquire(self: _lock): none
  {
    if self._batching
    {
      return
    }

    _async.send;
    _semaphore::runtime.wait;
    self._batching = true;

    when _lock l ->
    {
      (*l)._batching = false;
      _semaphore::loop.post
    }
  }
}
