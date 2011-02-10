
class ll {
  type itemType;
  var list: ll_entry(itemType);

  class a_class {
    var a: int;
    proc bar() { writeln(a); }
  }

  proc add_front(e) {
    list = new ll_entry(itemType, e, list);
  }

  proc remove_front() {
    var e: itemType;
    if list != nil {
      e = list.element;
      list = list.next;
    }
    return e;
  }

  proc add_back(e) {
    if list == nil then
      list = new ll_entry(itemType, e);
    else {
      var mylist = list;
      while mylist.next != nil do
        mylist = mylist.next;
      mylist.next = new ll_entry(itemType, e);
    }
  }

  proc remove_back() {
    var e: itemType;
    if list != nil {
      if list.next != nil {
        var mylist = list;
        while ((mylist.next != nil) && (mylist.next.next != nil)) do
          mylist = mylist.next;
        e = mylist.next.element;
        mylist.next = nil;
      }
      else {
        e = list.element;
        list = nil;
      }
    }
    return e;
  }

  proc contains(e)  {
    var mylist = list;
    while mylist != nil do
      if e == mylist.element then
        return true;
    return false;
  }

  proc remove_all_matching(e) {
    var mylist = list;
    if list == nil then
      return;
    while mylist.next != nil do
      if mylist.next.element == e then
        mylist.next = mylist.next.next;
      else
        mylist = mylist.next;
    // if the first element item in the list is equal to e, remove it
    if list.element == e then
      list = list.next;
  }

  proc reverse() {
    var mylist: ll_entry(itemType);
    var e: itemType;

    if list == nil then
      return;

    while list != nil {
      e = list.element;
      mylist = new ll_entry(itemType, e, mylist);
      list = list.next;
    }
    list = mylist;
  }

  proc concatenate_front(list2: ll(itemType)){
    if list2 == nil then
      return;

    var mylist = list2.list;
    while mylist != nil {
      add_front(mylist.element);
      mylist = mylist.next;
    }
  }

  proc print() {
    var mylist = list;
    while mylist != nil {
      writeln(mylist.element);
      mylist = mylist.next;
    }
  }

}

class ll_entry {
  // It would be better to make this nested within the ll class
  // But class nesting is not yet implemented
  type elementType;
  var element: elementType;
  var next: ll_entry(elementType);  
}

proc main(){
  var list: ll(int) = new ll(int);
  var list2: ll(int) = new ll(int);

  for i in 1..10 {
    list.add_front(i);
    list2.add_front(-i);
  }
  list.add_front(2);
  list.add_front(2);
  list.add_front(2);
  list.add_front(2);
  list.add_front(2);

  list.remove_all_matching(2);
  list.print();
  list.reverse();
  list.print();
  list.concatenate_front(list2);
  list2.remove_front();
  list.print();
}
