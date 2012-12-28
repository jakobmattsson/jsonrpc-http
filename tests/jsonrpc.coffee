should = require 'should'
_ = require 'underscore'
bufferstream = require 'bufferstream'
server = require('./coverage').require('jsonrpc')

listeners = []

echo = (method, args) ->
  listeners.forEach (listener) ->
    listener(method, _.toArray(args).slice(0, -1), _.last(args))

api =
  sum: (v1, v2, v3, callback) -> echo('sum', arguments)
  subtract: (minuend, subtrahend, callback) -> echo('subtract', arguments)
  update: (v1, v2, v3, v4, v5, callback) -> echo('update', arguments)
  notify_hello: (v, x, callback) -> echo('notify_hello', arguments)
  get_data: (callback) -> echo('get_data', arguments)

noErr = (callback) ->
  (err, rest...) ->
    should.not.exist err
    callback(rest...)





it "should be possible to construct an rpc-server without an output-stream", (done) ->
  rpc = server.construct()

  listeners.push (method, args, callback) ->
    callback(null, args[0] - args[1])

  rpc.answer {
    jsonrpc: "2.0"
    params: [23, 42]
    method: 'subtract'
  }, noErr (data) ->
    should.not.exists data
    done()




describe "rpc call", ->

  outputtedData = ""
  output = new bufferstream()
  output.on 'data', (buffer) ->
    outputtedData += buffer.toString()

  rpc = server.construct(output)

  rpc.add('sum', ['v1', 'v2', 'v3'], api.sum)
  rpc.add('subtract', ['minuend', 'subtrahend'], api.subtract)
  rpc.add('update', ['v1', 'v2', 'v3', 'v4', 'v5'], api.update)
  rpc.add('notify_hello', ['v', 'x'], api.notify_hello)
  rpc.add('get_data', [], api.get_data)

  beforeEach ->
    listeners = []
    outputtedData = ""



  it "should be not be possible to add something that have already been added", (done) ->
    f = -> rpc.add('update', ['x'], ->)
    f.should.throw("Function already added")
    done()



  it "should be possible to remove functions that have previously been added", (done) ->

    listeners.push (method, args, callback) ->
      callback(null, "done")

    rpc.answer {
      jsonrpc: "2.0"
      method: 'get_data'
      id: "1"
    }, noErr (data) ->
      data.should.eql
        jsonrpc: "2.0"
        id: "1"
        result: "done"

      rpc.remove('get_data')

      rpc.answer {
        jsonrpc: "2.0"
        method: 'get_data'
        id: "1"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          error:
            code: -32601
            message: "Method not found."

        rpc.add('get_data', [], api.get_data)
        done()



  describe "from the spec", ->

    it "with positional parameters (1)", (done) ->
      listeners.push (method, args, callback) ->
        callback(null, args[0] - args[1])

      rpc.answer {
        jsonrpc: "2.0"
        params: [42, 23]
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          result: 19
        done()



    it "with named parameters (1)", (done) ->
      listeners.push (method, args, callback) ->
        callback(null, args[0] - args[1])

      rpc.answer {
        jsonrpc: "2.0"
        params: { subtrahend: 23, minuend: 42 }
        method: 'subtract'
        id: "3"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "3"
          result: 19
        done()



    it "a notification (1)", (done) ->
      apiCalled = false
      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer {
        jsonrpc: "2.0"
        params: [1,2,3,4,5]
        method: 'update'
      }, noErr (data) ->
        apiCalled.should.be.true
        outputtedData.should.eql ''
        should.not.exist data
        done()



    it "a notification (2)", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer {
        jsonrpc: "2.0"
        method: 'foobar'
      }, noErr (data) ->
        apiCalled.should.be.false
        should.not.exist data
        done()



    it "of non-existent method", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer {
        jsonrpc: "2.0"
        method: 'foobar'
        id: "6"
      }, noErr (data) ->
        apiCalled.should.be.false
        data.should.eql
          jsonrpc: "2.0"
          id: "6"
          error:
            code: -32601
            message: "Method not found."
        done()



    it "with invalid Request object", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer {
        jsonrpc: "2.0"
        method: 1
        params: 'bar'
      }, noErr (data) ->
        apiCalled.should.be.false
        data.should.eql
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        done()



    it "with an empty Array", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer [], noErr (data) ->
        apiCalled.should.be.false
        data.should.eql
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        done()



    it "with an invalid Batch (but not empty)", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer [1], noErr (data) ->
        apiCalled.should.be.false
        data.should.eql [
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        ]
        done()



    it "with an invalid Batch", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answer [1,2,3], noErr (data) ->
        apiCalled.should.be.false
        data.should.eql [{
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        }, {
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        }, {
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        }]
        done()



    it "Batch", (done) ->
      counter = 0

      listeners.push (method, args, callback) ->
        if method == 'get_data' || method == 'sum' || method == 'subtract' || method == 'notify_hello'
          counter++
        if method == 'get_data'
          callback(null, ['hello', 5])
        if method == 'sum'
          callback(null, args.reduce(((acc, x) -> acc + x), 0))
        if method == 'subtract'
          callback(null, args[0] - args[1])
        if method == 'notify_hello'
          callback(null)

      rpc.answer [{
        jsonrpc: "2.0"
        method: "sum"
        params: [1, 2, 4]
        id: "1"
      }, {
        jsonrpc: "2.0"
        method: "notify_hello"
        params: [7]
      }, {
        jsonrpc: "2.0"
        method: "subtract"
        params: [42, 23]
        id: "2"
      }, {
        foo: "boo"
      }, {
        jsonrpc: "2.0"
        method: "foo.get"
        params: { name: "myself" }
        id: "5"
      }, {
        jsonrpc: "2.0"
        method: "get_data"
        id: "9"
      }], noErr (data) ->
        counter.should.eql 4
        data.should.eql [{
          jsonrpc: "2.0"
          id: "1"
          result: 7
        }, {
          jsonrpc: "2.0"
          id: "2"
          result: 19
        }, {
          jsonrpc: "2.0"
          id: null
          error:
            code: -32600
            message: "Invalid request."
        }, {
          jsonrpc: "2.0"
          id: "5"
          error:
            code: -32601
            message: "Method not found."
        }, {
          jsonrpc: "2.0"
          id: "9"
          result: ["hello", 5]
        }]
        done()



    it "Batch (all notification)", (done) ->
      called = []

      listeners.push (method, args, callback) ->
        called.push(method)
        callback(null)

      rpc.answer [{
        jsonrpc: "2.0"
        method: "notify_sum"
        params: [1, 2, 4]
      }, {
        jsonrpc: "2.0"
        method: "notify_hello"
        params: [7]
      }], noErr (data) ->
        called.should.eql ['notify_hello']
        should.not.exist data
        done()



  describe 'my own', ->

    it "without id, for a function that wants to return something", (done) ->
      listeners.push (method, args, callback) ->
        callback(null, args[0] - args[1])

      rpc.answer {
        jsonrpc: "2.0"
        params: [23, 42]
        method: 'subtract'
      }, noErr (data) ->
        should.not.exists data
        outputtedData.should.eql "Function 'subtract' called as notification but attempting to return data\n"
        done()



    it "leaving out the params object", (done) ->
      listeners.push (method, args, callback) ->
        args.length.should.eql 2
        should.not.exist args[0]
        should.not.exist args[1]
        callback(null, 42)

      rpc.answer {
        jsonrpc: "2.0"
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          result: 42
        done()



    it "passing too few parameters, by position", (done) ->
      listeners.push (method, args, callback) ->
        args.length.should.eql 2
        args[0].should.eql 100
        should.not.exist args[1]
        callback(null, 12345)

      rpc.answer {
        jsonrpc: "2.0"
        params: [100]
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          result: 12345
        done()



    it "passing too many parameters, by position", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        args.should.eql [100, 10, 1]
        callback(null, args[0] - args[1])

      rpc.answer {
        jsonrpc: "2.0"
        params: [100, 10, 1]
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        apiCalled.should.be.true
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          result: 90
        done()



    it "passing too few parameters, by name", (done) ->
      listeners.push (method, args, callback) ->
        args.length.should.eql 2
        should.not.exist args[0]
        args[1].should.eql 23
        callback(null, "some result")

      rpc.answer {
        jsonrpc: "2.0"
        params: { subtrahend: 23 }
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          result: "some result"
        done()



    it "passing too many parameters, by name", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback()

      rpc.answer {
        jsonrpc: "2.0"
        params: { somethingUnknown: 23, more: 12, subtrahend: 10  }
        method: 'subtract'
        id: "1"
      }, noErr (data) ->
        apiCalled.should.be.false
        data.should.eql
          jsonrpc: "2.0"
          id: "1"
          error:
            code: -32000
            message: 'Unknown parameters provided'
            data: ['more', 'somethingUnknown']
        done()



    it "should report errors returned from the api-function", (done) ->
      listeners.push (method, args, callback) ->
        callback(new Error("some error"))

      rpc.answer {
        jsonrpc: "2.0"
        method: "subtract"
        params: [100, 10]
        id: 123
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: 123
          error:
            code: -32001
            message: 'API-exception'
            data: 'some error'
        done()



    it "should catch errors raised by the api-function", (done) ->
      listeners.push (method, args, callback) ->
        throw new Error("uncaught error!!!")
        callback(null, 123)

      rpc.answer {
        jsonrpc: "2.0"
        method: "subtract"
        params: [100, 10]
        id: 123
      }, noErr (data) ->
        data.should.eql
          jsonrpc: "2.0"
          id: 123
          error:
            code: -32002
            message: 'Uncaught API-exception'
            data: "uncaught error!!!"
        done()


    it "should explicitly return an empty result if none is given", (done) ->
      listeners.push (method, args, callback) ->
        callback(null)

      rpc.answer {
        jsonrpc: "2.0"
        method: "subtract"
        params: [100, 10]
        id: 123
      }, noErr (data) ->
        data.should.eql
          id: 123
          result: null
          jsonrpc: "2.0"
        done()



    it "should give an error if the requested method does not exist", (done) ->
      rpc.answer {
        jsonrpc: "2.0"
        method: "shitface"
        params: [100, 10]
        id: 123
      }, noErr (data) ->
        data.should.eql
          id: 123
          error:
            code: -32601
            message: "Method not found."
          jsonrpc: "2.0"
        done()



  describe "jsonp", ->

    it "jsonp transport: with named parameters (1)", (done) ->
      listeners.push (method, args, callback) ->
        args.should.eql [42, 23]
        callback(null, args[0] - args[1])

      rpc.answerJSONP 'subtract', { callback: 'whatever', subtrahend: 23, minuend: 42 }, noErr (data) ->
        data.should.eql 'whatever({"id":"whatever","result":19,"jsonrpc":"2.0"})'
        done()



    it "jsonp transport: with too many parameters", (done) ->
      listeners.push (method, args, callback) ->
        args.should.eql [42, 23]
        callback(null, 'bla')

      rpc.answerJSONP 'subtract', { callback: 'whatever', subtrahend: 23, minuend: 42, test: 'value' }, noErr (data) ->
        data.should.eql 'whatever({"id":"whatever","error":{"code":-32000,"message":"Unknown parameters provided","data":["test"]},"jsonrpc":"2.0"})'
        done()



    it "jsonp transport: no parameters", (done) ->
      listeners.push (method, args, callback) ->
        args.should.eql [undefined, undefined]
        callback(null, "res")

      rpc.answerJSONP 'subtract', { callback: 'whatever' }, noErr (data) ->
        data.should.eql 'whatever({"id":"whatever","result":"res","jsonrpc":"2.0"})'
        done()



    it "jsonp transport: a notification (1)", (done) ->
      methods = []
      listeners.push (method, args, callback) ->
        methods.push(method)
        callback(null)

      rpc.answerJSONP 'update', {
        callback: 'mycallback'
        v1: 1
        v2: 2
        v3: 3
        v4: 4
        v5: 5
      }, noErr (data) ->
        methods.should.eql ['update']
        data.should.eql 'mycallback({"id":"mycallback","result":null,"jsonrpc":"2.0"})'
        done()



    it "jsonp transport - of non-existent method", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null)

      rpc.answerJSONP 'foobar', { callback: 'cb' }, noErr (data) ->
        apiCalled.should.be.false
        data.should.eql 'cb({"id":"cb","error":{"code":-32601,"message":"Method not found."},"jsonrpc":"2.0"})'
        done()



    it "jsonp transport: missing method", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null, 'result-data')

      rpc.answerJSONP null, { callback: 'whatever', subtrahend: undefined, minuend: 42 }, noErr (data) ->
        apiCalled.should.be.false
        done()



    it "jsonp transport: non-existing method", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null, 'result-data')

      rpc.answerJSONP 'shitface', { callback: 'whatever' }, noErr (data) ->
        apiCalled.should.be.false
        data.should.eql 'whatever({"id":"whatever","error":{"code":-32601,"message":"Method not found."},"jsonrpc":"2.0"})'
        done()



    it "jsonp transport: missing callback-parameter", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        callback(null, 'result-data')

      rpc.answerJSONP 'subtract', { subtrahend: undefined, minuend: 42 }, (err, data) ->
        err.should.eql 'Missing callback'
        should.not.exist data
        done()



    it "jsonp transport: parsing arguments (1)", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        args.should.eql [42, "23"]
        callback(null, 'result-data')

      rpc.answerJSONP 'subtract', { callback: 'whatever', subtrahend: '"23"', minuend: "42" }, noErr (data) ->
        apiCalled.should.be.true
        data.should.eql 'whatever({"id":"whatever","result":"result-data","jsonrpc":"2.0"})'
        done()



    it "jsonp transport: parsing arguments (2)", (done) ->
      apiCalled = false

      listeners.push (method, args, callback) ->
        apiCalled = true
        args.should.eql [42, { a: 1, b: 2 }]
        callback(null, 'result-data')

      rpc.answerJSONP 'subtract', { callback: 'whatever', subtrahend: '{"a":1,"b":2}', minuend: "42" }, noErr (data) ->
        apiCalled.should.be.true
        data.should.eql 'whatever({"id":"whatever","result":"result-data","jsonrpc":"2.0"})'
        done()
