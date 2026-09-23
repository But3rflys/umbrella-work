# table
Extensions for the built-in Lua table library.

table.IsEmpty(t: table) -> boolean
  Returns true if the table has no entries.
table.Length(t: table) -> integer
  Counts ALL entries (array + hash), unlike #t which only counts the sequence part.
table.Keys(t: table) -> table
  Returns a new array containing all keys of the table.
table.Values(t: table) -> table
  Returns a new array containing all values of the table.
table.Sum(t: table) -> number
  Returns the sum of all numeric values in the table. Non-numeric values are skipped.
table.Reverse(t: T[]) -> T[]
  *Generic: T* Returns a new array with the sequence part of t in reverse order.
table.CopyShallow(orig: T, [ignore_mt: boolean = false]) -> T
  *Generic: T : table* Creates a shallow copy of the table. Copies the metatable unless ignore_mt is true.
  ignore_mt: If true, the metatable is not copied
table.Copy(orig: T) -> T
  *Generic: T : table* Deep-copies a table with cycle detection. Metatables are preserved.
table.KvSwap(t: table, [v_to_true: boolean = false]) -> table
  Swaps keys and values. If v_to_true is true, all new values become true instead of the original key.
  v_to_true: If true, new values are true instead of the original key
table.Merge(...: table) -> table
  Concatenates array-part entries from all argument tables into a new array.
  ...: Tables to merge
table.MergeHm(...: table) -> table
  Merges all key-value pairs from argument tables into a new table. Later tables overwrite earlier ones.
  ...: Tables to merge
table.Diff(new_t: table, old_t: table) -> table
  Returns entries in new_t whose values differ from old_t (compared by rawequal).
table.Sorted(t: T[], [compare_func: fun(a: T, b: T):boolean = nil]) -> T[]
  *Generic: T* Sorts the table in-place via the built-in table.sort, then returns it.
  compare_func: Optional comparison function
table.Map(t: table, func: fun(value: any, key: any):any) -> table
  Applies func(value, key) to every entry and returns a new array of results.
  func: Callback func(value, key) -> new_value
table.Filter(t: T[], func: fun(value: T, key: integer):boolean) -> T[]
  *Generic: T* Returns a new array containing only entries for which func(value, key) returns true.
  func: Predicate func(value, key) -> boolean
table.Any(t: table, func: fun(value: any, key: any):boolean) -> boolean
  Returns true if func(value, key) returns true for at least one entry.
  func: Predicate func(value, key) -> boolean
table.All(t: table, func: fun(value: any, key: any):boolean) -> boolean
  Returns true if func(value, key) returns true for every entry.
  func: Predicate func(value, key) -> boolean
table.Find(t: table, element: any) -> any, any
  Finds the first entry matching element by raw equality. Returns value, key on match, or nil if not found.
  element: Element to search for
table.RemoveElement(t: table, element: any|function) -> boolean
  Removes the first matching element from the array-part of t. If element is a function, it is used as a predicate func(value, index) -> boolean. Otherwise, finds by raw equality. Shifts remaining elements down to maintain order.
  element: Element to find or predicate function
