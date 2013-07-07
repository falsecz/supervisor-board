class ProgramContainer
	constructor: ->
		@el = $('#processes')
		@groups = {}

	setData: (data) ->
		for group, items of data
			if @groups[group]
				p = @groups[group]
			else
				p = new Program group
				@groups[group] = p
				@el.append p.getBody()

			p.setData items


class Instance
	constructor: (@host) ->
		@el = $ """
			<div class="row-fluid instance">
				<div class="span3 host">host</div>
				<div class="span1 state">state</div>

				<div class="span2 uptime">
					xxxx
				</div>
				<div class="span3">
					<div class="btn-group buttons"></div>
				</div>
			</div>

		"""

		bg = @el.find('.buttons')
		bg.empty()

		startBtn = $ """<button class="btn btn-mini btn-successx start">Start</button>"""
		stopBtn = $ """<button class="btn btn-mini btn-inversex stop">Stop</button>"""
		tailBtn = $ """<button class="btn btn-mini btn-infox tail">Tail</button>"""

		#
		# if running
		# 	bg.append stopBtn
		# else
		bg.append startBtn
		bg.append stopBtn
		bg.append tailBtn
		#
		startBtn.click () =>
			return unless @data
			socket.emit 'start', {host: @data.host, name: @data.name}

		stopBtn.click () =>
			return unless @data
			socket.emit 'stop', {host: @data.host, name: @data.name}


	setData: (@data) ->
		row = @el
		uptime = new Date (data.start * 1000)


		row.find('.host').html data.hostname

		up = (data.now - data.stop)
		row.find('.uptime').html data.uptime





		running = no
		if data.statename is 'RUNNING'
			klass = "success"
			running = yes
		else if data.statename is 'STOPPED'
			klass = "info"
		else
			klass = "important"

		state = row.find('.state')
		state.html """<span class="label label-#{klass}">#{data.statename}</span></td>"""





	getElement: () ->
		@el

class Program
	constructor: (@group) ->
		@hosts = {}
		@body = $ """
			<div class="row-fluid program">
				<div class="span12 group">
					<div class="row-fluid">
						<div class="span4">
							<h5 class="title">name</h5>
							<div class="btn-group buttons"></div>
						</div>
						<div class="span8">
							<div class="span4-fluid instances">

							</div>
						</div>
					</div>

				</div>
			</div>
		"""
		@titleEl = @body.find '.title'
		@instancesEl = @body.find '.instances'
		@buttonsEl = @body.find '.buttons'


		startBtn = $ """<button class="btn btn-small btn-successx start">Start</button>"""
		stopBtn = $ """<button class="btn btn-small btn-inversex stop">Stop</button>"""
		tailBtn = $ """<button class="btn btn-small btn-infox tail">Tail</button>"""

		@buttonsEl.append startBtn
		@buttonsEl.append stopBtn
		@buttonsEl.append tailBtn

	setData: (data) ->


		for item in data
			@titleEl.html """
				#{item.name}

				"""

			if @hosts[item.host]
				h = @hosts[item.host]
			else
				h = new Instance item.host

				# TODO SORT
				@instancesEl.append h.getElement()
				@hosts[item.host] = h

			h.setData item








	getBody: () ->
		@body



startProcess = (host, name) ->
	$.get "/process/start/#{host}/#{name}", () ->
		alert 'done'

stopProcess = (host, name) ->
	$.get "/process/stop/#{host}/#{name}", () ->
		alert 'done'


container = new ProgramContainer


socket = io.connect()
socket.on 'processes', (processes) ->
	container.setData processes

socket.emit 'processes'


$.pnotify.defaults.history = false

socket.on 'error', (message) ->
	$.pnotify
		type: 'error'
		title: 'Error'
		text: message
