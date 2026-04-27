type matcher<'a>
type mockFn<'args, 'ret>
type spy<'args, 'ret>

/* Core */
@module("bun:test") external describe: (string, unit => unit) => unit = "describe"
@module("bun:test") external test: (string, unit => unit) => unit = "test"
@module("bun:test") external it: (string, unit => unit) => unit = "it"

@module("bun:test") external beforeAll: (unit => unit) => unit = "beforeAll"
@module("bun:test") external beforeEach: (unit => unit) => unit = "beforeEach"
@module("bun:test") external afterEach: (unit => unit) => unit = "afterEach"
@module("bun:test") external afterAll: (unit => unit) => unit = "afterAll"

/* Expect */
@module("bun:test") external expect: 'a => matcher<'a> = "expect"

/* Equality */
@send external toBe: (matcher<'a>, 'a) => unit = "toBe"
@send external toEqual: (matcher<'a>, 'a) => unit = "toEqual"
@send external toStrictEqual: (matcher<'a>, 'a) => unit = "toStrictEqual"

/* Truthiness */
@send external toBeTruthy: matcher<'a> => unit = "toBeTruthy"
@send external toBeFalsy: matcher<'a> => unit = "toBeFalsy"
@send external toBeNull: matcher<'a> => unit = "toBeNull"
@send external toBeUndefined: matcher<'a> => unit = "toBeUndefined"
@send external toBeDefined: matcher<'a> => unit = "toBeDefined"

/* Comparison */
@send external toBeGreaterThan: (matcher<'a>, 'a) => unit = "toBeGreaterThan"
@send external toBeGreaterThanOrEqual: (matcher<'a>, 'a) => unit = "toBeGreaterThanOrEqual"
@send external toBeLessThan: (matcher<'a>, 'a) => unit = "toBeLessThan"
@send external toBeLessThanOrEqual: (matcher<'a>, 'a) => unit = "toBeLessThanOrEqual"

/* Collections / strings */
@send external toContain: (matcher<'a>, 'b) => unit = "toContain"
@send external toMatch: (matcher<string>, string) => unit = "toMatch"
@send external toHaveLength: (matcher<'a>, int) => unit = "toHaveLength"

/* Exceptions */
@send external toThrow: matcher<unit => 'a> => unit = "toThrow"

/* Snapshot */
@send external toMatchSnapshot: matcher<'a> => unit = "toMatchSnapshot"

/* Mock assertions */
@send external toHaveBeenCalled: matcher<'a> => unit = "toHaveBeenCalled"
@send external toHaveBeenCalledTimes: (matcher<'a>, int) => unit = "toHaveBeenCalledTimes"
@send external toHaveBeenCalledWith: (matcher<'a>, 'b) => unit = "toHaveBeenCalledWith"

/* Negation */
@get external not: matcher<'a> => matcher<'a> = "not"

/* Mocking */
@module("bun:test")
external mock: (unit => 'a) => mockFn<unit, 'a> = "mock"

@module("bun:test")
external fn: (unit => 'a) => mockFn<unit, 'a> = "mock"

/* spyOn */
@module("bun:test")
external spyOn: ('obj, string) => spy<'args, 'ret> = "spyOn"