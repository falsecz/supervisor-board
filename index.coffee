require('cson-config').load()

async = require 'async'
xmlrpc = require 'xmlrpc'
util = require 'util'
express = require 'express'
{EventEmitter} = require 'events'



spclients = {}
hosts = process.config.hosts
unless hosts?.length
	console.log "Missing hosts in config.cson"
	process.exit 1

for host in hosts
	[hostname, port] = host.split ':'
	spclients[host] = xmlrpc.createClient({ host: hostname, port: port, path: '/RPC2'})


class Tail extends EventEmitter
	constructor: (@host, @name) ->
		@offset  = 0
		@_closed = no
		@_update()

	close: () ->
		clearInterval @_timer
		@_closed = yes
	_update: =>
		return if @_closed

		spclients[@host].methodCall 'supervisor.tailProcessStdoutLog', [@name, @offset, 1000], (err, data) =>
			return console.log err if err
			[text, @offset, overflow] = data

			if text
				@emit 'data',
					host: @host
					name: @name
					data: text

			@_timer = setTimeout @_update, 100


formatUptime = (diff) ->
	lead = (s) ->
		"0#{s}".slice -2

	sec = diff % 60
	diff = (diff - sec) / 60
	min = diff % 60
	diff = (diff - min) / 60
	hours = diff % 24
	diff = (diff - hours) / 24
	days = diff

	days + " days, " + lead(hours) + ":" + lead(min) + ":" + lead(sec)

findAllProcesses = (done) ->
	processes = []
	async.each hosts, (host, next) ->
		spclient = spclients[host]
		spclient.methodCall 'supervisor.getAllProcessInfo', [], (err, localProcesses) ->
			return next err if err
			for process in localProcesses
				hp = host.split(':')
				process.host = host
				process.hostname = hp[0]

				process.uptime = formatUptime(process.now - process.start)
				process.uptime = "" unless process.statename is 'RUNNING'

				processes.push process
			next()
	,(err) ->
		return done err if err
		groups = {}

		for process in processes
			groups[process.name] ?= []
			groups[process.name].push process

		done null, groups

app = express()


http = require('http')
server = http.createServer(app)
io = require('socket.io').listen(server);



timer = null

updating = no

updateProcesses = () ->
	return if updating

	updating = yes

	findAllProcesses (err, processes) ->
		updating = no
		clients = io.sockets.clients()
		for client in clients
			client.emit 'processes', processes

		delay = 1000
		delay = 500 unless clients.length
		# console.log delay
		# console.log updateProcesses
		timer = setTimeout updateProcesses, delay


updateProcesses()

updateNow = () ->
	unless updating
		clearInterval timer
		updateProcesses()

io.set 'log level', 1
io.sockets.on 'connection', (socket) ->
	socket.on 'processes', (o) ->
		updateNow()
		setTimeout () ->
			socket.emit 'error', 'mrdka'
		, 1000


	socket.on 'start', (o) ->
		console.log 'xxxx'
		client = spclients[o.host]
		client.methodCall 'supervisor.startProcess', [o.name] , (err, localProcesses) ->
			socket.emit 'error', err.faultString if err?.faultString
			updateNow()

	socket.on 'stop', (o) ->
		client = spclients[o.host]
		client.methodCall 'supervisor.stopProcess', [o.name] , (err, localProcesses) ->
			socket.emit 'error', err.faultString if err?.faultString
			updateNow()


	socket.on 'tail', (data) ->
		t = new Tail data.host, data.name
		t.on 'data', (data) ->
			socket.emit 'tail', data
		socket.on 'end', () ->
			t.close()



app.use (req, res, next) ->
	if req.url.match '/tail/'
		req.url = '/tail.html'

	next()



app.use express.static "#{__dirname}/public"

app.get '/processes', (req, res, next) ->
	findAllProcesses (err, processes) ->
		return next err if err
		# console.log processes
		res.json processes

app.get '/process/start/:host/:name', (req, res, next) ->
	client = clients[req.params.host]
	client.methodCall 'supervisor.startProcess', [req.params.name] , (err, localProcesses) ->
		res.json arguments

app.get '/process/stop/:host/:name', (req, res, next) ->
	client = clients[req.params.host]
	client.methodCall 'supervisor.stopProcess', [req.params.name] , (err, localProcesses) ->
		res.json arguments






server.listen process.config.port
console.log "Listening on #{process.config.port}"


