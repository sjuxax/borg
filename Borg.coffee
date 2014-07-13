path = require 'path'
fs = require 'fs'
_ = require 'lodash'
require 'sugar'
Logger = require './Logger'

module.exports =
class Borg
  # process
  log: -> Logger.out.apply Logger, arguments
  die: (reason) ->
    @log type: 'err', reason
    console.trace()
    process.exit 1
    return

  constructor: ({cwd, cmd}) ->
    @cwd = cwd or process.cwd()

  # async flow control
  _Q: []
  next: (err) => @_Q.splice 0, @_Q.length-1 if err; @_Q.shift()?.apply null, arguments
  then: (fn, args...) ->
    @die 'invalid function referenced' unless typeof fn is 'function'
    @_Q.push(=> args.push @next; fn.apply null, args); @
  finally: (fn, args...) => @_Q.push(-> fn.apply null, args); @next()

  # attributes
  networks: {}
  server: {}
  define: (o) => @server = _.merge @server, o
  default: (o) => @server = _.merge o, @server
  fqdn: (server) -> "#{server.datacenter}-#{server.env}-#{server.instance}-#{server.type}.#{server.tld}"

  eachServer: (cb) ->
    for datacenter, v of @networks.datacenters
      for type, vv of @networks[datacenter] when not _.contains ['_default', 'nat_networks'], type
        for instance, vvv of vv when not _.contains ['_default'], instance
          return if false is cb datacenter: datacenter, type: type, instance: instance

  getServerAttributes: (datacenter, type, instance, locals = {}) ->
    # flatten server attributes from hierarchical network structure;
    # an individual server's attributes are composed of:
    server = {}
    #  a) attributes which all instances in a specific datacenter share
    if @networks[datacenter]._default?
      server = _.merge server, @networks[datacenter]._default
    #  b) attributes which all instances of specific server type share
    if @networks[datacenter][type]._default?
      server = _.merge server, @networks[datacenter][type]._default
    #  c) specific per-instance attributes
    server = _.merge server, @networks[datacenter][type][instance]
    #  d) plus a few implicitly calculated attributes
    server.environment ||= 'development'
    server.datacenter = datacenter
    server.type = type
    server.instance = instance
    server.env = switch server.environment
      when 'development' then 'dev'
      when 'staging' then 'stage'
      when 'production' then 'prod'
      else server.environment
    server.fqdn = @fqdn server
    server.hostname = "#{server.type}#{server.instance}"
    for own dev, adapter of server.network when adapter.private
      server.private_ip = adapter.address
      break
    #  e) plus a few local attributes (overrides everything else)
    server = _.merge server, locals
    return server

  reloadAttributes: (pattern, locals) ->
    # load network map
    @networks = require path.join @cwd, 'attributes', 'networks'
    @server = {}
    # import default attributes
    @import @cwd, 'attributes', 'default'
    # find server matching pattern, override server attributes with matching network instance attributes
    @eachServer ({ datacenter, type, instance }) =>
      #console.log dc: datacenter, t: type, i: instance, pattern: pattern
      server = @getServerAttributes datacenter, type, instance, {}
      #console.log server: server, locals: locals
      # skip unless pattern matches
      return unless pattern is server.fqdn or # exact string match
        null isnt (new RegExp(pattern)).exec(server.fqdn) or # regex match
        ( # locals match
          locals.datacenter is server.datacenter and
          locals.environment is server.environment and
          locals.type is server.type and
          locals.instance is server.instance and
          locals.tld is server.tld
        )
      # found match
      server = @getServerAttributes datacenter, type, instance, locals
      @server = _.merge @server, server
      return false # stop searching for matching servers

  # scripts
  import: (paths...) ->
    p = path.join.apply null, paths
    @log "importing #{p}..."
    try
      stats = fs.statSync p
      if stats.isDirectory()
        @importCwd = p
    catch err
      if err?.code is 'ENOENT'
        @importCwd = path.dirname p
      else
        @die err
    finally
      (require p).apply @

  # api / cli
  assimilate: ({user, key, pass, host, port, scripts, locals}, cb) ->
    port ||= 22
    locals.ssh =
      user: user
      host: host
      port: port

    # load server attributes for named host
    @reloadAttributes host, locals

    #console.log "Network attributes: "+ JSON.stringify @networks, null, 2
    #console.log "Server attributes: "+ JSON.stringify @server, null, 2

    # connect via ssh
    Ssh = require './Ssh'
    @ssh = new Ssh user: user, pass: pass, host: host, port: port, key: key, (err) =>
      throw err if err # TODO: pass caught errors to callback

      # all resources come from a separate vendor repository
      @import @cwd, 'scripts', 'vendor', 'resources'

      # begin chaining script execution callbacks
      scripts = [ host ] unless scripts
      for script in scripts
        @import @cwd, 'servers', script
      # finish and execute chain

      console.log 'server:'+ JSON.stringify @server, null, 2
      @finally =>
        @ssh.close()
        setTimeout (-> cb null), 100













# TODO: support:
# borg cmd --sudo u:p@localhost:223 -- test blah
# borg cmd --sudo u:p@localhost:223 test blah
# borg assimilate developer:tunafish@10.1.10.24:22

#class OldBorg
#  constructor: (cmd) ->
#    targets = []
#    options = {}
#    args = []
#    last_option = null
#    for arg, ii in process.argv.slice 3
#      if match = arg.match(/^(.+?)(:(.+))?@(.+?)(:(.+))?$/)
#        targets.push user: match[1], pass: match[3], host: match[4], port: match[6]
#      else
#        if arg is '--'
#          options.eol = process.argv.slice(ii+4).join ' '
#          break
#        else if arg[0] is '-'
#          options[last_option = arg.split(/^--?/)[1]] = true
#        else if last_option isnt null
#          options[last_option] += ' '+arg
#          last_option = null
#        else
#          args.push arg
#    #console.log cmd: cmd, targets: targets, options: options, args: args
#    async = require 'async2'
#    flow = new async
#    for own k, target of targets
#      ((target) ->
#        flow.parallel (next) ->
#          Borg[cmd] target, options, next
#      )(target)
#    flow.go (err, results...) ->
#      if err
#        #process.stderr.write err+"\n"
#        Logger.out 'aborted with error.'
#        process.exit 1
#      else
#        Logger.out 'all done.'
#        process.exit 0
#
#  @rekey: (target, options, cb) ->
#
#  @assimilate: (target, options, cb) ->
#    # build node object
#    global.node =
#      default: f = (ns, v) ->
#        n = node
#        t = ns.split '.'
#        l = t.length - 1
#        for k, i in t
#          if i is l then n[k] = v
#          else if typeof n[k] isnt 'object' then n[k] = {}
#          n = n[k]
#        return
#      define: f
#      require: (ns, reason='') ->
#        n = node
#        for k in ns.split '.'
#          if n[k] is undefined then throw "Fatal: node.#{ns} is undefined. #{reason}"
#          n = n[k]
#        return n[k]
#    # load network map + apply attribute defaults
#    { networks, get_instance_attrs } = global.Network = require './Network'
#    global.node.networks = networks
#    # apply target attribute defaults
#    global.node = _.merge global.node, attrs = get_instance_attrs target.host
#    # apply script attribute defaults
#    require path.join process.cwd(), 'attributes', 'default'
#
#    # connect via ssh
#    global.ssh = new Ssh user: target.user, pass: target.pass, host: target.host, port: target.port, ->
#      global.assimilated = ->
#        ssh.close()
#        cb()
#      require path.join process.cwd(), 'scripts', 'vendor', 'resources'
#      require path.join process.cwd(), 'scripts', 'first'
#      require path.join process.cwd(), 'servers', "#{target.host}.coffee"
#      require path.join process.cwd(), 'scripts', 'last'
#
#  @cmd: (target, options, cb) ->
#    #console.log arguments
#    ssh = new Ssh user: target.user, pass: target.pass, host: target.host, port: target.port, ->
#      #if err then return Logger.out host: target.host, type: 'err', err
#      ssh.cmd options.eol, {}, (err) ->
#        ssh.close()
#        cb()
