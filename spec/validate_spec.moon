
import validate from require "lapis.validate"


run_with_errors = (fn) ->
  import capture_errors from require "lapis.application"
  req = {}
  capture_errors(fn) req
  req.errors

o = {
  age: ""
  name: "abc"
  height: "12234234"
}

tests = {
  {
    {
      { "age", exists: true }
      { "name", exists: true }
      { "rupture", exists: true, "CUSTOM MESSAGE COOL" }
    }

    { "age must be provided", "CUSTOM MESSAGE COOL" }
  }

  {
    {
      { "name", exists: true, min_length: 4 }
      { "age", min_length: 4 }
      { "height", max_length: 5 }
    }

    {
      "name must be at least 4 chars"
      "age must be at least 4 chars"
      "height must be at most 5 chars"
    }
  }

  {
    {
      { "height", is_integer: true }
      { "name", is_integer: true }
      { "age", is_integer: true }
    }

    {
      "name must be an integer"
      "age must be an integer"
    }
  }

  {
    {
      { "height", min_length: 4 }
    }

    nil
  }

  {
    {
      { "age", optional: true, max_length: 2 }
      { "name", optional: true, max_length: 2 }
    }

    {
      "name must be at most 2 chars"
    }
  }

  {
    {
      { "name", one_of: {"cruise", "control" } }
    }

    {
      "name must be one of cruise, control"
    }
  }

  {
    {
      { "name", one_of: {"bcd", "abc" } }
    }
  }


  {
    {
      { "name", matches_pattern: "bc$" }
      { "age", matches_pattern: "." }
    }

    {
      "age is not the right format"
    }
  }

}


describe "lapis.validate", ->
  for {input, output} in *tests
    it "should match", ->
      errors = validate o, input
      assert.same errors, output

  it "should get key with error", ->
    errors = validate o, {
      { "age", exists: true }
      { "name", exists: true }
      { "rupture", exists: true, "rupture is required" }
    }, {keys: true }

    assert.same errors, {
      age: "age must be provided",
      rupture: "rupture is required"
    }

  describe "assert_valid", ->
    it "throws error", ->
      import assert_valid from require "lapis.validate"

      assert.same {
        "thing must be provided"
      }, run_with_errors ->
        assert_valid { }, {
          {"thing", exists: true}
        }

    it "passes on valid input", ->
      import assert_valid from require "lapis.validate"

      done = false

      assert.same nil, run_with_errors ->
        assert_valid {
          thing: "cool"
        }, {
          {"thing", exists: true}
        }

        done = true

      assert.true done

    it "operates on tableshape type", ->
      import assert_valid from require "lapis.validate"
      types = require "lapis.validate.types"

      assert.same {
       'id: expected database ID integer'
       'name: expected text between 1 and 10 characters'
      }, run_with_errors ->
        res = assert_valid {}, types.params_shape {
          {"id", types.db_id}
          {"name", types.limited_text 10 }
        }

        error "should not get here..."

      done = false
      assert.same nil, run_with_errors ->
        res, state = assert_valid {
          id: "15"
          name: "Deep"
        }, types.params_shape {
          {"id", types.db_id\tag "cool" }
          {"name", types.limited_text(10) / (s) -> "-#{s}-" }
        }

        assert.same {
          id: 15
          name: "-Deep-"
        }, res

        assert.same {
          cool: 15
        }, state

        done = true

      assert done


describe "lapis.validate.types", ->
  it "creates assert type", ->
    types = require "lapis.validate.types"

    assert_string = types.assert_error(types.string)

    assert.same {
      [[expected type "string", got "number"]]
    }, run_with_errors ->
      assert_string 77

    assert.same nil, run_with_errors ->
      assert_string "hello"

  describe "params_shape", ->
    types = require "lapis.validate.types"

    it "works with assert_error", ->
      t = types.assert_error types.params_shape {
        {"good", types.one_of {"yes", "no"} }
        {"dog", types.string\tag "sweet"}
      }

      assert.same {
        [[good: expected "yes", or "no"]]
        [[dog: expected type "string", got "nil"]]
      }, run_with_errors ->
        t\transform {}

      assert.same {
        {
          dog: "fool"
          good: "no"
        }
        {
          sweet: "fool"
        }
      }, {
        t\transform { good: "no", dog: "fool", bye: "heheh" }
      }

    it "fails to create object with invalid spec", ->
      assert.has_error(
        ->
          types.params_shape {
            item: "zone"
          }
        [[params_shape: Invalid validation specification object: expected type "table", got "string" (index: item)]]
      )

      assert.has_error(
        ->
          types.params_shape {
            {"one", "two"}
          }
        [[params_shape: Invalid validation specification object: field 2: expected tableshape type (index: 1)]]
      )

      assert.has_error(
        ->
          types.params_shape {
            {"one", types.string, fart: "zone"}
          }
        [[params_shape: Invalid validation specification object: extra fields: "fart" (index: 1)]]
      )

    it "tests basic object", ->
      test_object = types.params_shape {
        {"one", types.string}
        {"two", types.string / (s) -> "-#{s}-"}
      }

      assert.same {
        nil
        {
          [[params: expected type "table", got "string"]]
        }
      }, { test_object "wtf" }

      assert.same {
        nil
        {
          [[params: expected type "table", got "nil"]]
        }
      }, { test_object! }

      assert.same {
        nil
        {
          [[one: expected type "string", got "nil"]]
          [[two: expected type "string", got "nil"]]
        }
      }, { test_object {} }

      assert.same {
        nil
        {
          [[one: expected type "string", got "number"]]
          [[two: expected type "string", got "boolean"]]
        }
      }, { test_object {one: 55, two: true, whatthe: "heck"} }

      assert.same {
        nil
        {
          [[two: expected type "string", got "nil"]]
        }
      }, { test_object { one: "yes", another: false } }

      assert.same {
        nil
        {
          [[one: expected type "string", got "boolean"]]
        }
      }, { test_object { two: "sure", one: false } }

      assert.same {
        {
          one: "whoa"
          two: "-sure-"
        }
      }, { test_object\transform { two: "sure", one: "whoa", ignore: 99 } }


    it "always returns new object", ->
      s = types.params_shape {
        {"color", types.literal "blue"}
      }

      input = { color: "blue" }
      output = s\transform input
      assert.same input, output
      assert.false input == output, "input and output should be distinct objects"

    it "tests object with state", ->
      -- TODO:

    it "test labels", ->
      t = types.params_shape {
        {"name", label: false, types.string}
        {"inner", label: false, types.params_shape {
          {"one", label: false, types.string}
          {"two", types.string}
        }}
      }

      _, errors = t\transform { }

      assert.same {
        [[expected type "string", got "nil"]]
        [[params: expected type "table", got "nil"]]
      }, errors

      _, errors = t\transform {
        name: false
        inner: {
          one: 23892
          two: 23892
        }
      }

      assert.same {
        [[expected type "string", got "boolean"]]
        [[expected type "string", got "number"]]
        [[two: expected type "string", got "number"]]
      }, errors


    it "test nested validate", ->
      test_object = types.params_shape {
        {"alpha", types.one_of {"one", "two"} }
        {"two", types.params_shape {
          {"one", as: "sure", error: "you messed up", types.string\tag "one"}
          {"two", label: "The Two", types.string / (s) -> "-#{s}-"}
        }}

        {"optional", label: "Optionals", types.nil + types.params_shape {
          {"confirm", types.literal "true" }
        }}
      }

      assert.same [[
params type {
  alpha: "one", or "two"
  two: params type {
    one: type "string" tagged "one"
    two: type "string"
  }
  optional: type "nil", or params type {confirm: "true"}
}]], tostring test_object

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: params: expected type "table", got "nil"]]
        }
      }, { test_object {} }

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: params: expected type "table", got "nil"]]
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: "fart"} }

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: you messed up]]
          [[two: The Two: expected type "string", got "nil"]]
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: {}, two: {}} }

      assert.same {
        nil
        {
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: {}, alpha: "one", two: {one: "yes", two: "no"}} }


      assert.same {
        {
          alpha: "one"
          optional: {confirm: "true"}
          two: {
            sure: "yes"
            two: "-no-"
          }
        }

        {
          one: "yes"
        }
      }, {
        test_object\transform {
          optional: { confirm: "true", junk: "yes"}
          alpha: "one"
          two: {1,2,3, for: true, one: "yes", two: "no"}
        }
      }

    it "numeric indicies", ->
      t = types.params_shape {
        {1, types.string}
        {2, types.number}
      }

      assert.same {"tuple", 200}, (t\transform { "tuple", 200 })
      assert.same {"tuple", 200}, (t\transform { "tuple", 200, "extra", things: "true" })

      assert.same {
        nil, {
          [[2: expected type "number", got "string"]]
        }
      }, {
        t\transform { "one", "two" }
      }

      assert.same {
        nil, {
          [[1: expected type "string", got "boolean"]]
          [[2: expected type "number", got "boolean"]]
        }
      }, {
        t\transform { false, true, "give" }
      }

  describe "params_map", ->
    types = require "lapis.validate.types"

    it "tests empty object", ->
      map_t = types.params_map types.db_id, types.table
      result, err = map_t\transform {}
      assert.same {}, result
      assert.falsy err

    it "tests invalid input type", ->
      params_t = types.params_map(types.db_id, types.table)
      assert.same {nil, {[[params map: expected type "table", got "string"]]}}, { params_t\transform("not a table") }

    it "tests simple map", ->
      map_t = types.params_map types.db_id\tag("keys[]"), types.params_shape {
        {"name", types.string\tag("names[]")}
      }

      res, state = map_t\transform {
        "55": {name: "hello", exlude: 12}
        "99": {name: "world"}
      }

      assert.same {
        [55]: {name: "hello"}
        [99]: {name: "world"}
      }, res

      assert.same 2, #state.names
      assert.same 2, #state.keys

      assert.same {
        [55]: true
        [99]: true
      }, {k, true for k in *state.keys}

      assert.same {
        ["hello"]: true
        ["world"]: true
      }, {k, true for k in *state.names}

    -- default iterator if there is only one error
    it "single failure cases", ->
      map_t = types.params_map types.db_id\tag("keys[]"), types.params_shape {
        {"name", types.string\tag("names[]")}
        {"custom", types.boolean + types.nil}
      }

      assert.same {
        nil
        { [[item key: expected database ID integer]] }
      }, {
        map_t\transform {
          "hello": { name: false } -- value not tested
          "23": {name: "world"}
        }
      }

      assert.same {
        nil
        {
          [[item 99: name: expected type "string", got "boolean"]]
          [[item 99: custom: expected type "boolean", or type "nil"]]
        }
      }, {
        map_t\transform {
          "99": { name: false, custom: 239 }
          "23": { name: "world" }
        }
      }


    it "custom join_error", ->
      map_t = types.params_map types.db_id\tag("keys[]"), types.params_shape({
        {"name", types.string\tag("names[]")}
        {"custom", types.boolean + types.nil}
      }), {
        join_error: (err, key, value, error_type) =>
          "map[#{error_type}]: #{key} #{err}"
      }

      assert.same {
        nil
        { [[map[key]: hello expected database ID integer]] }
      }, {
        map_t\transform {
          "hello": { name: false } -- value not tested
          "23": {name: "world"}
        }
      }

      assert.same {
        nil
        {
          [[map[value]: 99 name: expected type "string", got "boolean"]]
          [[map[value]: 99 custom: expected type "boolean", or type "nil"]]
        }
      }, {
        map_t\transform {
          "99": { name: false, custom: 239 }
          "23": { name: "world" }
        }
      }

    it "ordered_pairs", ->
      map_t = types.params_map types.db_id\tag("keys[]"), types.params_shape({
        {"name", types.string\tag("names[]")}
        {"custom", types.boolean + types.nil}
      }), {
        iter: types.params_map.ordered_pairs
      }

      res, state = map_t\transform {
        "55": {name: "hello", exlude: 12}
        "99": {name: "world"}
      }

      assert.same {
        keys: {55, 99}
        names: {"hello", "world"}
      }, state

    -- we use custom iterator to ensure that order is consistent
    it "multiple failure cases", ->
      map_t = types.params_map types.db_id\tag("keys[]"), types.params_shape({
        {"name", types.string\tag("names[]")}
        {"custom", types.boolean + types.nil}
      }), {
        iter: types.params_map.ordered_pairs
      }

      assert.same {
        nil
        {
          [[item 99: name: expected type "string", got "boolean"]]
          [[item 99: custom: expected type "boolean", or type "nil"]]
          [[item key: expected database ID integer]]
        }
      }, {
        map_t\transform {
          "hello": { name: false } -- value not tested
          "23": {name: "world"}
          "99": { name: false, custom: 239 }
        }
      }

    it "transforms key and value", ->
      change_key = types.string / (s) -> "*#{s}*"
      change_value = types.table * types.clone / (t) ->
        t.visited = true
        t

      map_t = types.params_map change_key, change_value

      og_object = {
        one: {thing: "zing"}
      }

      assert.same {
        "*one*": {thing: "zing", visited: true}
      }, map_t\transform og_object

      assert.same {
        one: {thing: "zing"}
      }, og_object

    it "strips tuples that transform to nil", ->
      map_t = types.params_map types.string + types.number / nil, types.string + types.number / nil

      assert.same {
        hello: "world"
      }, map_t\transform {
        hello: "world"
        [55]: "zone"
        song: 404
      }

  describe "params_array", ->
    types = require "lapis.validate.types"

    it "empty object", ->
      shape = types.params_array(types.string)
      assert.same {}, shape\transform {}
      assert.same {
        nil, {[[params array: expected type "table", got "boolean"]]}
      }, { shape\transform true }

    it "array with simple type", ->
      shape = types.params_array(types.string)
      assert.same {"hello", "world"}, shape\transform {"hello", "world"}

      assert.same {
        nil, {[[item 1: expected type "string", got "boolean"]]}
      }, { shape\transform {true} }

      assert.same {
        nil, {
          [[item 1: expected type "string", got "number"]]
          [[item 3: expected type "string", got "boolean"]]
        }
      }, { shape\transform {7, "true", false} }

    it "contains params_shape", ->
      t = types.params_array types.params_shape {
        {"name", types.string}
        {"age", types.number}
      }

      assert.same { }, t\transform { }

      input = {
        {name: "John", age: 30}
        {name: "Jane", age: 28}
      }
      output = t\transform input

      assert.same input, output
      assert input != output, "Input and output should be distinct objects"

      assert.same {
        nil, {
          [[item 1: name: expected type "string", got "nil"]]
          [[item 3: age: expected type "number", got "string"]]
          [[item 4: name: expected type "string", got "nil"]]
          [[item 4: age: expected type "number", got "nil"]]
        }
      }, {
        t\transform {
          {name: nil, age: 30}
          {name: "Dane", age: 2389}
          {name: "Jane", age: "cool"}
          {}
        }
      }

    it "very nested object", ->
      t = types.params_array types.params_shape {
        {"id", types.number}
        {"tags", types.params_array types.params_shape {
          {"name", types.string}
        }}
      }

      assert.same {}, t\transform {}

      assert.same {
        nil, {
          [[item 1: id: expected type "number", got "nil"]]
          -- this is not ideal (params: )
          [[item 1: tags: params array: expected type "table", got "boolean"]]
        }
      }, {
        t\transform {
          { tags: false }
        }
      }

      assert.same {
        nil, {
          [[item 2: tags: item 1: params: expected type "table", got "boolean"]]
          [[item 3: tags: item 1: params: expected type "table", got "string"]]
          [[item 3: tags: item 2: params: expected type "table", got "function"]]
        }
      }, {
        t\transform {
          { id: 1, tags: {} }
          { id: 2, tags: { false } }
          { id: 3, tags: { "true", -> } }
        }
      }

      -- valid object
      assert.same {
        {
          {
            id: 1234
            tags: {
              {name: "hello"}
            }
          }

        }
      }, {
        t\transform {
          {
            id: 1234
            tags: {
              { name: "hello" }
            }
          }
        }
      }

    it "params_array length type", ->
      t = types.params_array types.params_shape({
        {"name", types.string}
      }), length: types.range(5,6)

      assert.same {
        nil
        {"length expected range from 5 to 6"}
      }, { t\transform {} }

    it "custom iterator", ->
      t = types.params_array types.params_shape({
        {"name", types.string}
      }), iter: pairs

      out = t\transform {
        "one": {name: "cool"}
        {name: "zone", age: 5}
      }

      assert.same out, {
        {name: "zone"}
        {name: "cool"}
      }

      assert.same {
        nil, {
          [[item 1: name: expected type "string", got "number"]]
          [[item one: name: expected type "string", got "boolean"]]
        }
      }, {
        t\transform {
          "one": {name: false}
          {name: 9999, age: 5}
        }
      }

    it "captures state", ->
      t = types.params_array types.partial({
        title: types.string\tag "things[]"
      }) + types.string\tag("things[]") / (o) -> {title: o}

      res, state = assert t\transform {
        { title: "cool" }
        { title: "zone", age: 5 }
        "whazt"
      }

      assert.same {
        things: {
          "cool", "zone", "whazt"
        }
      }, state

      assert.same {
        { title: "cool" }
        { title: "zone", age: 5 }
        { title: "whazt"}
      }, res


  describe "flatten_errors", ->
    types = require "lapis.validate.types"

    it "flattens errors", ->
      t = types.flatten_errors types.params_shape {
        {"id", types.string}
        {"name", types.string}
      }

      assert.same {nil, [[params: expected type "table", got "boolean"]]}, { t\transform true}

      assert.same {nil, [[id: expected type "string", got "nil", name: expected type "string", got "nil"]]}, { t\transform {}}

      assert.same {nil, [[name: expected type "string", got "nil"]]}, { t\transform {
        id: "hello"
      }}

      assert.same {
        {
          id: "hello"
          name: "world"
        }
      }, { t\transform {
        id: "hello"
        name: "world"
      }}

    it "passes flat errors through", ->
      t = types.flatten_errors types.string + types.number

      assert.same {nil, [[expected type "string", or type "number"]]}, {t\transform true}
      assert.same {nil, [[expected type "string", or type "number"]]}, {t\transform true}

  describe "multi_params", ->
    types = require "lapis.validate.types"

    it "tests two params objects", ->
      t = types.multi_params {
        types.params_shape {
          {"id", types.db_id}
        }
        types.params_shape {
          {"name", types.valid_text}
        }
      }

      assert.same {
        nil, {[[params: expected type "table", got "nil"]]}
      }, { t\transform nil }

      assert.same {
        nil, {[[params: expected type "table", got "string"]]}
      }, { t\transform "hello" }

      assert.same {
        nil, {
          "id: expected database ID integer"
          "name: expected valid text"
        }
      }, { t\transform {} }

      assert.same {
        nil, {
          "name: expected valid text"
        }
      }, { t\transform {id: 234} }

      assert.same {
        nil, {
          "id: expected database ID integer"
        }
      }, { t\transform {name: "hello"} }

      assert.same {
        {
          id: 12
          name: "hello"
        }
      }, { t\transform {name: "hello", thing: "ff", id: 12} }


    it "tests multi params objects with conditional", ->
      t = types.multi_params {
        types.params_shape {
          {"id", types.db_id}
        }
        types.params_shape({
          {"type", types.literal "a"}
          {"name", types.valid_text}
        }) + types.params_shape {
          {"type", types.literal "b"}
          {"label", types.valid_text}
        }
      }

      -- this is hideous, but it's a lot of work to determine how to show the
      -- error message in an ideal way
      assert.same {
        nil, {
          [[id: expected database ID integer]]
          [[expected params type {
  type: "a"
  name: valid text
}, or params type {
  type: "b"
  label: valid text
}]]
        }
      }, { t\transform {} }

      assert.same {
        nil, {
          [[expected params type {
  type: "a"
  name: valid text
}, or params type {
  type: "b"
  label: valid text
}]]
        }
      }, { t\transform {
        id: "23"
      } }

      assert.same {
        nil, {
          [[expected params type {
  type: "a"
  name: valid text
}, or params type {
  type: "b"
  label: valid text
}]]
        }
      }, { t\transform {
        type: "b"
        name: "fart"
        id: "23"
      } }

      assert.same {
        nil, {
          [[expected params type {
  type: "a"
  name: valid text
}, or params type {
  type: "b"
  label: valid text
}]]
        }
      }, { t\transform {
        type: "a"
        label: "sum"
        id: "23"
      } }

      assert.same {
        {
          id: 23
          type: "a"
          name: "nem"
        }
      }, { t\transform {
        id: "23"
        type: "a"
        name: "nem"
      } }

      assert.same {
        {
          id: 99
          type: "b"
          label: "cool"
        }
      }, { t\transform {
        id: "99"
        type: "b"
        label: "cool"
      } }

  describe "empty", ->
    types = require "lapis.validate.types"

    it "tests empty", ->
      assert.same true, types.empty nil
      assert.same true, types.empty ""
      assert.same true, types.empty "   "
      assert.same true, types.empty "\t\n"

      assert.same {nil, "expected empty"}, { types.empty -> }
      assert.same {nil, "expected empty"}, { types.empty true }
      assert.same {nil, "expected empty"}, { types.empty "hello" }
      assert.same {nil, "expected empty"}, { types.empty {} }

    it "tranforms empty", ->
      assert.same nil, types.empty\transform nil
      assert.same nil, types.empty\transform ""
      assert.same nil, types.empty\transform "   "
      assert.same nil, types.empty\transform "\t\n"

  describe "cleaned_text", ->
    import cleaned_text from require "lapis.validate.types"

    it "invalid type", ->
      assert.same {
        nil
        "expected text"
      }, {
        cleaned_text\transform 100
      }

      assert.same {
        nil
        "expected text"
      }, {
        cleaned_text\transform nil
      }

    it "empty string", ->
      assert.same {
        ""
      }, {
        cleaned_text\transform ""
      }

    it "regular string", ->
      assert.same {
        "hello world\r\nyeah"
      }, {
        cleaned_text\transform "hello world\r\nyeah"
      }

    it "removes bad chars", ->
      assert.same {
        "ummandf"
      }, {
        cleaned_text\transform "\008\000umm\127and\200f"
      }

  describe "valid_text", ->
    import valid_text from require "lapis.validate.types"

    it "invalid type", ->
      assert.same {
        nil
        "expected valid text"
      }, {
        valid_text\transform 100
      }

      assert.same {
        nil
        "expected valid text"
      }, {
        valid_text\transform nil
      }

    it "empty string", ->
      assert.same {
        ""
      }, {
        valid_text\transform ""
      }

    it "regular string", ->
      assert.same {
        "hello world\r\nyeah"
      }, {
        valid_text\transform "hello world\r\nyeah"
      }

    it "fails on bad chars", ->
      assert.same {
        nil
        "expected valid text"
      }, {
        valid_text\transform "\008\000umm\127and\200f"
      }

  describe "trimmed_text", ->
    import trimmed_text from require "lapis.validate.types"

    it "empty string", ->
      assert.same {
        nil
        "expected text"
      }, {
        trimmed_text\repair ""
      }

    it "nil value", ->
      assert.same {
        nil
        'expected valid text'
      }, {
        trimmed_text\repair nil
      }

    it "bad type", ->
      assert.same {
        nil
        'expected valid text'
      }, {
        trimmed_text\repair {}
      }

    it "trims text", ->
      assert.same {
        "trimz"
      }, {
        trimmed_text\transform " trimz   "
      }

  describe "limited_text", ->
    import limited_text, trimmed_text from require "lapis.validate.types"

    it "passes valid text", ->
      assert.same "hello", limited_text(10)\transform "hello"
      assert.same "hello", limited_text(5)\transform "hello"
      assert.same "hello", limited_text(10)\transform "   hello           "
      assert.same "hello", limited_text(10)\transform "  hello   \t  \n    "

      assert.same "💁👌🎍😍", limited_text(4)\transform "💁👌🎍😍"

    it "fails invalid input", ->
      assert.same {nil, "expected text between 1 and 4 characters"}, { limited_text(4)\transform "\0\0\0" }

    it "fails with text outside range", ->
      assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "helloworldthisfails" }
      assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "" }

  describe "truncated_text", ->
    import truncated_text from require "lapis.validate.types"

    it "invalid input", ->
      assert.same {
        nil,
        "expected valid text"
      }, {
        truncated_text(5)\transform true
      }

    it "empty string", ->
      assert.same {
        nil,
        "expected text"
      }, {
        truncated_text(5)\transform ""
      }

    it "1 char string", ->
      assert.same {
        "a"
      }, {
        truncated_text(5)\transform "a"
      }

    it "5 char string", ->
      assert.same {
        "abcde"
      }, {
        truncated_text(5)\transform "abcde"
      }

    it "6 char string", ->
      assert.same {
        "abcde"
      }, {
        truncated_text(5)\transform "abcdef"
      }

    it "very long strong", ->
      assert.same {
        "abcde"
      }, {
        truncated_text(5)\transform "abcdef"\rep 100
      }

    it "unicode string", ->
      assert.same {
        "基本上獲得"
      }, {
        truncated_text(5)\transform "基本上獲得全國軍"
      }


  it "db_id", ->
    import db_id from require "lapis.validate.types"
    assert.same {nil, "expected database ID integer"}, {db_id\transform "5.5"}
    assert.same {nil, "expected database ID integer"}, {db_id\transform 5.5}

    assert.same {5}, {db_id\transform 5}
    assert.same {5}, {db_id\transform "5"}
    assert.same {5}, {db_id\transform " 5"}
    assert.same {nil, "expected database ID integer"}, {db_id\transform "fjwekfwejfwe"}

    assert.same {0}, {db_id\transform "0"}
    assert.same {0}, {db_id\transform 0}
    assert.same {
      nil
      "expected database ID integer"
    }, {db_id\transform "239203280932932803023920302302302032203280328038203820380232802032083232239023820328903283209382039238209382032"}

    -- too large number
    assert.same {
      nil
      "expected database ID integer"
    }, {db_id\transform "92147483647"}

    -- too large number
    assert.same {
      nil
      "expected database ID integer"
    }, {db_id\transform "-34"}

    assert.same {
      nil
      "expected database ID integer"
    }, {db_id\transform -1}

    assert.same {
      nil
      "expected database ID integer"
    }, {db_id\transform 10^18}

  it "db_enum", ->
    import db_enum from require "lapis.validate.types"
    import enum from require "lapis.db.base_model"

    Types = enum {
      default: 1
      flash: 2
      unity: 3
      java: 4
      html: 5
    }

    t = db_enum Types

    assert.same {
      Types.flash
    }, { t\transform "flash" }

    assert.same {
      Types.flash
    }, { t\transform Types.flash }

    assert.same {
      Types.flash
    }, { t\transform "#{Types.flash }" }

    assert.same {
      nil
      "expected enum(default, flash, unity, java, html)"
    }, { t\transform "flahs" }

    assert.same {
      nil
      "expected enum(default, flash, unity, java, html)"
    }, { t\transform "9" }

    assert.same {
      nil
      "expected enum(default, flash, unity, java, html)"
    }, { t\transform 9 }

describe "lapis.validate.with_params", ->
  it "constructs from table", ->
    import with_params from require "lapis.validate"
    import db_id from require "lapis.validate.types"

    fn = with_params {
      {"id", db_id}
    }, (params) =>
      assert.same {
        id: 12
      }, params
      "success"

    assert.same {
      "id: expected database ID integer"
    }, run_with_errors ->
      fn { params: {} }

    assert.same {
      "id: expected database ID integer"
    }, run_with_errors ->
      fn { params: { id: "fart" } }

    assert.same "success", fn { params: { id: "12" } }
    assert.same "success", fn { params: { id: "12", ignore: "thing" } }

  it "constructs from tableshape", ->
    import with_params from require "lapis.validate"
    import types from require "tableshape"

    shape = types.shape { id: types.number }

    fn = with_params shape, (params) =>
      assert.same {
        id: 12
      }, params
      "success"

    assert.same {
      [[field "id": expected type "number", got "nil"]]
    }, run_with_errors ->
      fn { params: {} }

    assert.same {
      [[field "id": expected type "number", got "string"]]
    }, run_with_errors ->
      fn { params: { id: "fart" } }

    assert.same {
      [[extra fields: "ignore"]]
    }, run_with_errors ->
      assert.same "success", fn { params: { id: 12, ignore: "thing" } }

    assert.same "success", fn { params: { id: 12 } }

  it "passes state", ->
    import with_params from require "lapis.validate"
    import db_id from require "lapis.validate.types"

    fn = with_params {
      {"id", db_id\tag "hello"}
    }, (params, state, rest) =>
      assert.same {
        id: 12
      }, params

      assert.same {
        hello: 12
      }, state

      assert.same "cool", rest

      "success"

    assert.same "success", fn { params: { id: 12 } }, "cool"
