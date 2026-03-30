use print = "https://github.com/sylvanc/print" "main";

main(): i32
{
  let count = 0;

  let t = timer t ->
  {
    if count < 5
    {
      print "tick";
      count = count + 1;
      t 500
    }
  }

  t 0;

  stdin.start (in, data, size) ->
  {
    if size == 0
    {
      print "eof";
      in.close
    }
    else if data(0) == 'q'
    {
      print "quit";
      in.close
    }
    else
    {
      print::out.print "*"
    }
  }

  0
}
