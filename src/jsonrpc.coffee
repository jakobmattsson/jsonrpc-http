_ = require 'underscore'
async = require 'async'



getParams = (params, methodData) ->
  if Array.isArray(params)
    arr = params
    while arr.length < methodData.length
      arr.push(undefined)
    { result: arr }
  else
    extra = _.difference(Object.keys(params), methodData)
    if extra.length > 0
      { error: _.sortBy(extra, (x) -> x) }
    else
      { result: methodData.map (x) -> params[x] }



resolve = (dict, bod, debugstream, callback) ->

  if Array.isArray(bod) || typeof bod != 'object'
    return callback({
      id: null
      error:
        code: -32600
        message: 'Invalid request.'
    })

  # Make sure the request can be parsed
  if (bod.id != null && typeof(bod.id) != 'undefined' && typeof(bod.id) != 'string' && typeof(bod.id) != 'number') || typeof(bod.method) != 'string' || (typeof(bod.params) != 'object' && typeof(bod.params) != 'undefined')
    return callback({
      id: if (typeof(bod.id) != 'string' && typeof(bod.id) != 'number') then null else bod.id
      error:
        code: -32600
        message: 'Invalid request.'
    })

  # Abort if the method does not exist
  if !dict[bod.method]?
    if !bod.id?
      return callback()
    else
      return callback({
        id: bod.id
        error:
          code: -32601
          message: 'Method not found.'
      })

  # Figure out which parameters to use for the api-function
  apiParameters = getParams(bod.params ? [], dict[bod.method].args)
  if apiParameters.error
    return callback({
      id: bod.id
      error:
        code: -32000
        message: 'Unknown parameters provided'
        data: apiParameters.error
    })

  cb = (err, data) ->
    if !bod.id?
      debugstream.write("Function '#{bod.method}' called as notification but attempting to return data\n") if data?
      callback()
    else
      if err
        callback({ id: bod.id, error: { code: -32001, message: 'API-exception', data: err.message } })
      else
        callback({ id: bod.id, result: data ? null })

  try
    dict[bod.method].func.apply(null, apiParameters.result.concat([cb]))
  catch ex
    callback({ id: bod.id, error: { code: -32002, message: 'Uncaught API-exception', data: ex.message } })



exports.construct = (debugstream) ->

  dict = {}

  answer = (startBody, sender) ->
    bod = if Array.isArray(startBody) then startBody else [startBody]

    return sender(null, {
      jsonrpc: '2.0'
      id: null
      error:
        code: -32600
        message: 'Invalid request.'
    }) if bod.length == 0

    async.map bod, (b, callback) ->
      resolve dict, b, debugstream, (result) ->
        callback(null, result)
    , (err, output) ->

      output = output.filter((x) -> x)

      output.forEach (o) ->
        o.jsonrpc = '2.0'

      if Array.isArray(startBody)
        if output.length == 0
          sender()
        else
          sender(null, output)
      else
        if output[0]?
          sender(null, output[0])
        else
          sender()


  answer: answer
  add: (method, args, func) ->
    throw new Error("Function already added") if dict[method]?
    dict[method] = { args: args, func: func }
  remove: (method) -> delete dict[method]
  answerJSONP: (method, qs, callback) ->
    return callback("Missing callback") if !qs.callback?

    pars = _.omit(qs, 'callback')
    pars = _.object _.pairs(pars).map ([k, v]) ->
      par = null
      try
        par = JSON.parse(v)
      catch ex
        par = v
      [k, par]

    bod = {
      jsonrpc: '2.0'
      id: qs.callback
      method: method
      params: pars
    }

    answer bod, (err, data) ->
      return callback(err) if err?
      callback(null, "#{qs.callback}(#{JSON.stringify(data)})")
