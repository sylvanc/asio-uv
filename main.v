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
      t 100
    }
  }

  t 0;
  0
}
