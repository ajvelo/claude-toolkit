# TypeScript strict-mode gotchas

Things that bite when `strict: true` is on (`strictNullChecks`,
`noImplicitAny`, `strictFunctionTypes`, `strictBindCallApply`,
`strictPropertyInitialization`, `noImplicitThis`, `alwaysStrict`, plus
`exactOptionalPropertyTypes`).

---

## `any` sneaks in through `JSON.parse`

**Symptom:** you parse a response and the shape is wrong downstream, but
TypeScript never warned you.

**Why:** `JSON.parse` returns `any`. Everything downstream inherits `any`
and silently forfeits type checking.

**How to apply:** type it explicitly at the boundary with a validator
(zod, valibot, a hand-rolled type guard). Never let `any` leak past the
network layer.

```ts
const RawUser = z.object({ id: z.number(), email: z.string() });
type User = z.infer<typeof RawUser>;

async function getUser(id: number): Promise<User> {
  const res = await fetch(`/users/${id}`);
  return RawUser.parse(await res.json());
}
```

---

## `Object.keys` widens to `string[]`

**Symptom:** iterating keys of a typed object, TypeScript complains you
can't index a typed object with a `string`.

**Why:** `Object.keys(obj)` returns `string[]`, not `(keyof T)[]`. This is
intentional: the object could have extra keys at runtime that aren't in
the type.

**How to apply:** narrow with a typed cast at the call site only when you
control the object's provenance:

```ts
for (const k of Object.keys(obj) as (keyof typeof obj)[]) {
  use(obj[k]);
}
```

Prefer `Object.entries()` when you need values too; it returns
`[string, T[keyof T]][]` which is usually fine to work with as-is.

---

## `exactOptionalPropertyTypes` changes what `?` means

**Symptom:** code that worked yesterday fails with "Type `undefined` is not
assignable to type `string`" when you try to pass an explicit `undefined`.

**Why:** without `exactOptionalPropertyTypes`, `foo?: string` means
`string | undefined`. With it on, `foo?: string` means "the key may be
absent, but if present must be a string" — explicit `undefined` is a
type error.

**How to apply:** either don't include the key at all, or type the field
as `string | undefined` and drop the `?`. The flag forces you to pick.

---

## Array destructuring gives you `T | undefined`

**Symptom:** `const [first] = arr;` and then `first.length` errors with
"`first` is possibly undefined."

**Why:** `strictNullChecks` plus `noUncheckedIndexedAccess` makes every
array access return `T | undefined`, because arrays can be empty.

**How to apply:** three options, pick per situation:
- Check: `if (arr.length === 0) return; const [first] = arr;`
- Assert when you're certain: `const [first] = arr; if (!first) throw new Error("unreachable");`
- Prefer `.at(0)` which returns `T | undefined` explicitly — makes the
  possibility visible at the call site.

Avoid `arr[0]!` as a default; it hides the check and survives refactors
that make the array actually empty.

---

## `as const` and discriminated unions

**Symptom:** you return a literal object and the type widens to `string`
and `number` instead of the exact literals you wrote. Discriminated
unions don't narrow correctly.

**Why:** without `as const`, TypeScript infers the widest possible type.

**How to apply:** annotate literal shapes with `as const` when the exact
values matter for type narrowing:

```ts
function classify(n: number) {
  if (n < 0) return { kind: "negative", value: n } as const;
  if (n === 0) return { kind: "zero" } as const;
  return { kind: "positive", value: n } as const;
}
```

The resulting union now narrows precisely when you check `kind`.

---

## `Promise<T> | T` is not interchangeable with `Awaited<T>`

**Symptom:** a generic function takes `T | Promise<T>` and `T` narrows to
the union, or conversely unwraps incorrectly.

**Why:** TypeScript keeps the union alive unless you force unwrapping.
Return types of `async` functions automatically unwrap (`Promise<Promise<X>>` collapses to `Promise<X>`), but generic parameters do not.

**How to apply:** use `Awaited<T>` when you're declaring a function that
accepts either a value or a promise:

```ts
async function retry<T>(
  fn: () => T | Promise<T>,
  attempts = 3,
): Promise<Awaited<T>> {
  // ...
}
```

---

## `readonly T[]` and `T[]` are not assignment-compatible in one direction

**Symptom:** you get "The type 'readonly X[]' is 'readonly' and cannot be
assigned to the mutable type 'X[]'."

**Why:** a function expecting `X[]` might mutate the array. Passing it a
`readonly X[]` would silently break the caller's invariant.

**How to apply:** make function parameters `readonly` whenever the
function doesn't mutate them. This is both a correctness signal and
reduces friction for callers passing immutable data.

```ts
function sum(xs: readonly number[]): number { ... }
```

Always works, whether callers pass `[1, 2, 3]` or `readonly number[]`.

---

## `unknown` is not `any`, and that's the whole point

**Symptom:** migrating away from `any` feels like fighting the compiler.

**Why:** `unknown` requires type narrowing before use. `any` silently
accepts anything. Swapping `any` for `unknown` surfaces every unsafe
operation you were doing before.

**How to apply:** treat `unknown` as the default for values crossing a
trust boundary (network, disk, user input). Narrow with `typeof`,
`instanceof`, or a schema validator before reading properties.

```ts
function handle(payload: unknown) {
  if (typeof payload === "string") { /* narrow — payload is string */ }
  else if (payload instanceof Error) { /* narrow — Error instance */ }
  else { /* still unknown, handle accordingly */ }
}
```

---

## `noUnusedParameters` versus `_`-prefixed conventions

**Symptom:** a callback signature forces you to accept an argument you
don't use, and `noUnusedParameters` flags it.

**Why:** TS treats unused parameters as code smell, but callback
signatures are contracts you can't change.

**How to apply:** prefix the parameter name with an underscore. TS
treats `_ignored` as intentionally unused and suppresses the warning.

```ts
items.map((_item, index) => index);
```

Don't remove the parameter; it changes the function's arity and callers
may rely on it.
